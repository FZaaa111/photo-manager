import Foundation
import SwiftData

/// 照片元数据（来自 PhotoKit，用于与缓存对账）。
struct AssetMeta: Sendable, Equatable {
    let id: String
    var creationDate: Date?
    var modificationDate: Date?
    var pixelWidth: Int
    var pixelHeight: Int
    var burstIdentifier: String?
    var isFavorite: Bool
    var isScreenshot: Bool = false
}

struct BasicAnalysis: Sendable {
    let id: String
    let sharpness: Double
    let dHash: UInt64
}

struct DeepAnalysis: Sendable {
    let id: String
    let featurePrint: Data?
    let faceQuality: Double?
}

/// SwiftData 访问都收敛在这个 actor 里，对外只暴露 Sendable 的值类型。
@ModelActor
actor RecordStore {
    /// 与相册对账：新增 / 更新 / 删除缓存，返回全部记录。
    func sync(_ metas: [AssetMeta]) throws -> [AnalysisRecord] {
        let existing = try modelContext.fetch(FetchDescriptor<AssetRecord>())
        var byID = Dictionary(existing.map { ($0.localIdentifier, $0) }, uniquingKeysWith: { first, _ in first })
        var liveIDs = Set<String>()

        for meta in metas {
            liveIDs.insert(meta.id)
            if let record = byID[meta.id] {
                if record.modificationDate != meta.modificationDate {
                    record.resetAnalysis()
                    record.modificationDate = meta.modificationDate
                    record.pixelWidth = meta.pixelWidth
                    record.pixelHeight = meta.pixelHeight
                }
                record.creationDate = meta.creationDate
                record.burstIdentifier = meta.burstIdentifier
                record.isFavorite = meta.isFavorite
                record.isScreenshot = meta.isScreenshot
            } else {
                let record = AssetRecord(
                    localIdentifier: meta.id,
                    modificationDate: meta.modificationDate,
                    creationDate: meta.creationDate,
                    pixelWidth: meta.pixelWidth,
                    pixelHeight: meta.pixelHeight,
                    burstIdentifier: meta.burstIdentifier,
                    isFavorite: meta.isFavorite,
                    isScreenshot: meta.isScreenshot
                )
                modelContext.insert(record)
                byID[meta.id] = record
            }
        }

        for (id, record) in byID where !liveIDs.contains(id) {
            modelContext.delete(record)
            byID[id] = nil
        }
        try modelContext.save()
        return byID.values.map(\.snapshot)
    }

    func records(ids: Set<String>) throws -> [AnalysisRecord] {
        let list = Array(ids)
        let descriptor = FetchDescriptor<AssetRecord>(
            predicate: #Predicate { list.contains($0.localIdentifier) }
        )
        return try modelContext.fetch(descriptor).map(\.snapshot)
    }

    func allRecords() throws -> [AnalysisRecord] {
        try modelContext.fetch(FetchDescriptor<AssetRecord>()).map(\.snapshot)
    }

    func apply(basic results: [BasicAnalysis]) throws {
        try update(ids: results.map(\.id)) { record in
            guard let r = results.first(where: { $0.id == record.localIdentifier }) else { return }
            record.sharpness = r.sharpness
            record.dHashBits = Int64(bitPattern: r.dHash)
        }
    }

    func apply(deep results: [DeepAnalysis]) throws {
        try update(ids: results.map(\.id)) { record in
            guard let r = results.first(where: { $0.id == record.localIdentifier }) else { return }
            record.featurePrint = r.featurePrint
            record.faceQuality = r.faceQuality
        }
    }

    func apply(hashes: [(id: String, hash: String)]) throws {
        try update(ids: hashes.map(\.id)) { record in
            record.contentHash = hashes.first(where: { $0.id == record.localIdentifier })?.hash
        }
    }

    func apply(fileSizes: [(id: String, size: Int64)]) throws {
        try update(ids: fileSizes.map(\.id)) { record in
            if let size = fileSizes.first(where: { $0.id == record.localIdentifier })?.size {
                record.fileSize = size
            }
        }
    }

    // MARK: 忽略列表

    func ignoredIDs() throws -> Set<String> {
        Set(try modelContext.fetch(FetchDescriptor<IgnoredAsset>()).map(\.localIdentifier))
    }

    func ignore(_ ids: [String], reason: String) throws {
        let already = try ignoredIDs()
        for id in ids where !already.contains(id) {
            modelContext.insert(IgnoredAsset(localIdentifier: id, reason: reason))
        }
        try modelContext.save()
    }

    func unignore(_ ids: [String]) throws {
        let list = ids
        let descriptor = FetchDescriptor<IgnoredAsset>(
            predicate: #Predicate { list.contains($0.localIdentifier) }
        )
        for item in try modelContext.fetch(descriptor) {
            modelContext.delete(item)
        }
        try modelContext.save()
    }

    // MARK: -

    private func update(ids: [String], _ mutate: (AssetRecord) -> Void) throws {
        guard !ids.isEmpty else { return }
        let list = ids
        let descriptor = FetchDescriptor<AssetRecord>(
            predicate: #Predicate { list.contains($0.localIdentifier) }
        )
        for record in try modelContext.fetch(descriptor) {
            mutate(record)
        }
        try modelContext.save()
    }
}
