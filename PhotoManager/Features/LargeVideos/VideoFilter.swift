import Foundation

enum VideoSortKey: String, CaseIterable, Identifiable, Sendable {
    case sizeDescending
    case durationDescending
    case dateAscending
    case dateDescending

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sizeDescending: "体积从大到小"
        case .durationDescending: "时长从长到短"
        case .dateAscending: "拍摄时间从旧到新"
        case .dateDescending: "拍摄时间从新到旧"
        }
    }
}

enum VideoSizePreset: Int64, CaseIterable, Identifiable, Sendable {
    case any = 0
    case mb50 = 50_000_000
    case mb100 = 100_000_000
    case mb500 = 500_000_000
    case gb1 = 1_000_000_000

    var id: Int64 { rawValue }

    var title: String {
        switch self {
        case .any: "不限"
        case .mb50: "> 50 MB"
        case .mb100: "> 100 MB"
        case .mb500: "> 500 MB"
        case .gb1: "> 1 GB"
        }
    }
}

enum VideoDurationPreset: Double, CaseIterable, Identifiable, Sendable {
    case any = 0
    case sec30 = 30
    case min1 = 60
    case min5 = 300
    case min10 = 600

    var id: Double { rawValue }

    var title: String {
        switch self {
        case .any: "不限"
        case .sec30: "> 30 秒"
        case .min1: "> 1 分钟"
        case .min5: "> 5 分钟"
        case .min10: "> 10 分钟"
        }
    }
}

/// 大视频筛选条件。纯值类型，便于单元测试。
struct VideoFilter: Equatable, Sendable {
    var minSize: VideoSizePreset = .mb100
    var minDuration: VideoDurationPreset = .any
    /// 仅保留拍摄时间早于该日期的视频（用于"清理很久以前的视频"）。
    var shotBefore: Date?
    var sortKey: VideoSortKey = .sizeDescending

    var isDefault: Bool { self == VideoFilter() }

    func apply(to items: [VideoItem]) -> [VideoItem] {
        let filtered = items.filter { item in
            guard item.fileSize >= minSize.rawValue else { return false }
            guard item.duration >= minDuration.rawValue else { return false }
            if let shotBefore {
                // 没有拍摄时间的视频无法判断，保守起见不展示。
                guard let date = item.creationDate, date < shotBefore else { return false }
            }
            return true
        }
        return sorted(filtered)
    }

    private func sorted(_ items: [VideoItem]) -> [VideoItem] {
        switch sortKey {
        case .sizeDescending:
            return items.sorted { $0.fileSize > $1.fileSize }
        case .durationDescending:
            return items.sorted { $0.duration > $1.duration }
        case .dateAscending:
            return items.sorted { ($0.creationDate ?? .distantFuture) < ($1.creationDate ?? .distantFuture) }
        case .dateDescending:
            return items.sorted { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }
        }
    }
}
