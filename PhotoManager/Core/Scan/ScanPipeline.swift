import Foundation
import Photos

enum ScanPhase: Sendable {
    case syncing
    case analyzing
    case deepAnalyzing
    case fileSizes
    case hashing

    var title: String {
        switch self {
        case .syncing: "正在读取相册…"
        case .analyzing: "正在分析清晰度…"
        case .deepAnalyzing: "正在比对相似照片…"
        case .fileSizes: "正在统计文件大小…"
        case .hashing: "正在校验文件内容…"
        }
    }
}

struct ScanProgress: Sendable {
    var phase: ScanPhase
    var completed: Int
    var total: Int

    var fraction: Double? {
        total > 0 ? Double(completed) / Double(total) : nil
    }
}

/// 增量扫描流水线：与相册对账 → 只计算缓存里缺失的字段 → 写回缓存。
/// 所有方法都支持通过取消所在 Task 来中断，已完成的批次不会丢失。
final class ScanPipeline: Sendable {
    typealias ProgressHandler = @Sendable (ScanProgress) -> Void

    let store: RecordStore

    /// 并行分析的宽度，兼顾速度与内存 / 发热。
    private let width = 4
    private let chunkSize = 200

    init(store: RecordStore) {
        self.store = store
    }

    // MARK: - 对外接口

    /// 与相册对账，返回全部照片的缓存记录（不做任何分析）。
    func syncLibrary(progress: ProgressHandler) async throws -> [AnalysisRecord] {
        progress(ScanProgress(phase: .syncing, completed: 0, total: 0))
        let metas = Self.enumerateImageMetas()
        return try await store.sync(metas)
    }

    /// 同步并为所有照片计算清晰度与 dHash。
    func scanSharpness(progress: @escaping ProgressHandler) async throws -> [AnalysisRecord] {
        let records = try await syncLibrary(progress: progress)
        let pending = records.filter { $0.sharpness == nil || $0.dHash == nil }.map(\.id)

        await process(pending, phase: .analyzing, width: width, progress: progress) { id -> BasicAnalysis? in
            guard let image = await ThumbnailLoader.analysisImage(for: id, side: CGFloat(BlurDetector.analysisSide)),
                  let gray = GrayImage.make(from: image, maxSide: BlurDetector.analysisSide)
            else { return nil }
            return BasicAnalysis(
                id: id,
                sharpness: BlurDetector.sharpness(of: gray),
                dHash: PerceptualHash.dHash(of: gray)
            )
        } commit: { results in
            try? await self.store.apply(basic: results)
        }
        try Task.checkCancellation()
        return try await store.allRecords()
    }

    /// 相似照片分组。仅对通过粗筛的候选计算（较贵的）特征向量。
    func scanSimilar(level: SimilarityLevel, progress: @escaping ProgressHandler) async throws -> [[AnalysisRecord]] {
        let records = try await scanSharpness(progress: progress)

        let candidateIDs = SimilarGrouper.coarseCandidateIDs(records, level: level)
        let pending = records.filter { candidateIDs.contains($0.id) && $0.featurePrint == nil }.map(\.id)

        await process(pending, phase: .deepAnalyzing, width: width, progress: progress) { id -> DeepAnalysis? in
            guard let image = await ThumbnailLoader.analysisImage(for: id, side: 360) else { return nil }
            return DeepAnalysis(
                id: id,
                featurePrint: FeaturePrint.archivedFeaturePrint(for: image),
                faceQuality: FeaturePrint.faceQuality(for: image)
            )
        } commit: { results in
            try? await self.store.apply(deep: results)
        }
        try Task.checkCancellation()

        let fresh = try await store.allRecords()
        let cache = FeatureDistanceCache()
        let idGroups = SimilarGrouper.group(fresh, level: level, distance: cache.distance)

        // 只为分组成员补齐文件大小，用于展示可释放空间。
        let memberIDs = Set(idGroups.flatMap { $0 })
        await fillFileSizes(for: fresh.filter { memberIDs.contains($0.id) && $0.fileSize == 0 }.map(\.id), progress: progress)
        try Task.checkCancellation()

        let sized = try await store.records(ids: memberIDs)
        let byID = Dictionary(uniqueKeysWithValues: sized.map { ($0.id, $0) })
        return idGroups.map { $0.compactMap { byID[$0] } }
    }

    /// 为指定资源读取并缓存原图文件大小。
    func fillFileSizes(for ids: [String], progress: @escaping ProgressHandler) async {
        await process(ids, phase: .fileSizes, width: width, progress: progress) { id -> (id: String, size: Int64)? in
            guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else { return nil }
            let size = AssetResourceInfo.photoFileSize(of: asset)
            return size > 0 ? (id, size) : nil
        } commit: { results in
            try? await self.store.apply(fileSizes: results)
        }
    }

    /// 重复照片分组：先用文件大小 + 尺寸预分桶，只对同桶的资源读取内容算 SHA256。
    func scanDuplicates(progress: @escaping ProgressHandler) async throws -> [[AnalysisRecord]] {
        var records = try await syncLibrary(progress: progress)

        await fillFileSizes(for: records.filter { $0.fileSize == 0 }.map(\.id), progress: progress)
        try Task.checkCancellation()

        records = try await store.allRecords()
        let needHash = DuplicateGrouper.candidateBuckets(records)
            .flatMap { $0 }
            .filter { $0.contentHash == nil }
            .map(\.id)

        // 读取原图数据 I/O 重，降低并行度。
        await process(needHash, phase: .hashing, width: 2, progress: progress) { id -> (id: String, hash: String)? in
            guard let hash = await ContentHasher.sha256(forLocalIdentifier: id) else { return nil }
            return (id, hash)
        } commit: { results in
            try? await self.store.apply(hashes: results)
        }
        try Task.checkCancellation()

        let fresh = try await store.allRecords()
        let byID = Dictionary(uniqueKeysWithValues: fresh.map { ($0.id, $0) })
        return DuplicateGrouper.group(fresh).map { $0.compactMap { byID[$0] } }
    }

    // MARK: - 内部

    private static func enumerateImageMetas() -> [AssetMeta] {
        let options = PHFetchOptions()
        // 默认只返回连拍的代表帧；相似检测需要看到所有帧。
        options.includeAllBurstAssets = true
        let result = PHAsset.fetchAssets(with: .image, options: options)

        var metas: [AssetMeta] = []
        metas.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            metas.append(
                AssetMeta(
                    id: asset.localIdentifier,
                    creationDate: asset.creationDate,
                    modificationDate: asset.modificationDate,
                    pixelWidth: asset.pixelWidth,
                    pixelHeight: asset.pixelHeight,
                    burstIdentifier: asset.burstIdentifier,
                    isFavorite: asset.isFavorite,
                    isScreenshot: asset.mediaSubtypes.contains(.photoScreenshot)
                )
            )
        }
        return metas
    }

    /// 分批并行处理：每批内最多 `width` 个任务同时运行，批末统一写缓存并上报进度。
    private func process<T: Sendable, R: Sendable>(
        _ items: [T],
        phase: ScanPhase,
        width: Int,
        progress: ProgressHandler,
        transform: @escaping @Sendable (T) async -> R?,
        commit: ([R]) async -> Void
    ) async {
        guard !items.isEmpty else { return }
        progress(ScanProgress(phase: phase, completed: 0, total: items.count))

        var done = 0
        for start in stride(from: 0, to: items.count, by: chunkSize) {
            if Task.isCancelled { return }
            let chunk = Array(items[start..<min(start + chunkSize, items.count)])

            let results: [R] = await withTaskGroup(of: R?.self) { group in
                var iterator = chunk.makeIterator()
                var running = 0
                while running < width, let item = iterator.next() {
                    group.addTask { await transform(item) }
                    running += 1
                }
                var collected: [R] = []
                while let result = await group.next() {
                    if let result { collected.append(result) }
                    if !Task.isCancelled, let item = iterator.next() {
                        group.addTask { await transform(item) }
                    }
                }
                return collected
            }

            await commit(results)
            done += chunk.count
            progress(ScanProgress(phase: phase, completed: done, total: items.count))
        }
    }
}
