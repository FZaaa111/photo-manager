import Foundation
import Observation

/// 阈值与筛选逻辑，独立成纯函数便于测试。
enum BlurryFilter {
    static let defaultThreshold = 100.0
    static let thresholdRange = 10.0...500.0

    /// 清晰度低于阈值的照片，按从模糊到清晰排序。
    static func blurry(
        from records: [AnalysisRecord],
        threshold: Double,
        ignored: Set<String>,
        includeScreenshots: Bool
    ) -> [AnalysisRecord] {
        records
            .filter { record in
                guard let sharpness = record.sharpness else { return false }
                guard sharpness < threshold else { return false }
                guard !ignored.contains(record.id) else { return false }
                return includeScreenshots || !record.isScreenshot
            }
            .sorted {
                let l = $0.sharpness ?? 0, r = $1.sharpness ?? 0
                return l == r ? $0.id < $1.id : l < r
            }
    }
}

@MainActor
@Observable
final class BlurryPhotosViewModel {
    private(set) var records: [AnalysisRecord] = []
    private(set) var ignored: Set<String> = []
    private(set) var state: ScanState = .idle
    var selection = Set<String>()
    var threshold = BlurryFilter.defaultThreshold
    var includeScreenshots = false
    var errorMessage: String?

    private var scanTask: Task<Void, Never>?

    var blurry: [AnalysisRecord] {
        BlurryFilter.blurry(
            from: records,
            threshold: threshold,
            ignored: ignored,
            includeScreenshots: includeScreenshots
        )
    }

    func scan(using services: AppServices) {
        scanTask?.cancel()
        state = .scanning(ScanProgressSnapshot(ScanProgress(phase: .syncing, completed: 0, total: 0)))
        let pipeline = services.pipeline
        let store = services.store

        scanTask = Task { [weak self] in
            let report: ScanPipeline.ProgressHandler = { progress in
                Task { @MainActor in
                    guard let self, self.state.isScanning else { return }
                    self.state = .scanning(ScanProgressSnapshot(progress))
                }
            }
            do {
                let result = try await pipeline.scanSharpness(progress: report)
                let ignoredIDs = try await store.ignoredIDs()
                guard let self else { return }
                self.records = result
                self.ignored = ignoredIDs
                self.selection.formIntersection(self.blurry.map(\.id))
                self.state = .done
            } catch is CancellationError {
                self?.state = .idle
            } catch {
                self?.state = .failed(error.localizedDescription)
            }
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        state = .idle
    }

    func selectAllVisible() {
        selection = Set(blurry.map(\.id))
    }

    func pruneSelection() {
        selection.formIntersection(blurry.map(\.id))
    }

    func deleteSelected() async {
        let ids = Array(selection)
        do {
            try await PhotoDeletionService.delete(localIdentifiers: ids)
            let removed = Set(ids)
            records.removeAll { removed.contains($0.id) }
            selection.subtract(removed)
        } catch {
            if !PhotoDeletionService.isUserCancelled(error) {
                errorMessage = error.localizedDescription
            }
        }
    }

    func ignoreSelected(using store: RecordStore) async {
        let ids = Array(selection)
        do {
            try await store.ignore(ids, reason: "blurry")
            ignored.formUnion(ids)
            selection.subtract(ids)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
