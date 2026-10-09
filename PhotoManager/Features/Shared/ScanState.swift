import Foundation

enum ScanState: Equatable {
    case idle
    case scanning(ScanProgressSnapshot)
    case done
    case failed(String)

    var isScanning: Bool {
        if case .scanning = self { return true }
        return false
    }
}

/// ScanProgress 的可比较 / 可展示快照（ScanPhase 不要求 Equatable，这里只保留展示需要的字段）。
struct ScanProgressSnapshot: Equatable {
    var title: String
    var completed: Int
    var total: Int

    init(_ progress: ScanProgress) {
        title = progress.phase.title
        completed = progress.completed
        total = progress.total
    }

    var fraction: Double? {
        total > 0 ? Double(completed) / Double(total) : nil
    }
}
