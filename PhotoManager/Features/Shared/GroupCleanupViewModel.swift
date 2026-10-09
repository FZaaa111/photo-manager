import Foundation
import Observation

/// 相似照片与重复照片共用的视图模型：扫描 → 分组 → 合并。
@MainActor
@Observable
final class GroupCleanupViewModel {
    let kind: GroupKind
    var level: SimilarityLevel = .standard
    private(set) var groups: [PhotoGroup] = []
    private(set) var state: ScanState = .idle
    var errorMessage: String?

    private var scanTask: Task<Void, Never>?

    init(kind: GroupKind) {
        self.kind = kind
    }

    var totalReclaimable: Int64 {
        groups.reduce(0) { $0 + $1.reclaimableBytes }
    }

    var totalRemovable: Int {
        groups.reduce(0) { $0 + $1.removable.count }
    }

    // MARK: 扫描

    func scan(using pipeline: ScanPipeline) {
        scanTask?.cancel()
        state = .scanning(ScanProgressSnapshot(ScanProgress(phase: .syncing, completed: 0, total: 0)))
        let kind = kind
        let level = level

        scanTask = Task { [weak self] in
            let report: ScanPipeline.ProgressHandler = { progress in
                Task { @MainActor in
                    guard let self, self.state.isScanning else { return }
                    self.state = .scanning(ScanProgressSnapshot(progress))
                }
            }
            do {
                let raw: [[AnalysisRecord]]
                switch kind {
                case .similar: raw = try await pipeline.scanSimilar(level: level, progress: report)
                case .duplicate: raw = try await pipeline.scanDuplicates(progress: report)
                }
                guard let self else { return }
                self.groups = raw.compactMap { PhotoGroup.make(from: $0, kind: kind) }
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

    // MARK: 编辑与合并

    func setKeep(_ assetID: String, in groupID: String) {
        guard let index = groups.firstIndex(where: { $0.id == groupID }),
              groups[index].members.contains(where: { $0.id == assetID })
        else { return }
        groups[index].keepID = assetID
    }

    func merge(_ group: PhotoGroup) async {
        await perform([group.plan], removing: Set([group.id]))
    }

    func mergeAll() async {
        await perform(groups.map(\.plan), removing: Set(groups.map(\.id)))
    }

    private func perform(_ plans: [MergePlan], removing groupIDs: Set<String>) async {
        do {
            try await PhotoDeletionService.merge(plans)
            groups.removeAll { groupIDs.contains($0.id) }
        } catch {
            if !PhotoDeletionService.isUserCancelled(error) {
                errorMessage = error.localizedDescription
            }
        }
    }
}
