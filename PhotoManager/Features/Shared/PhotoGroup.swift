import Foundation

enum GroupKind: Sendable {
    /// 视觉相近
    case similar
    /// 内容完全相同
    case duplicate

    var navigationTitle: String {
        switch self {
        case .similar: "相似照片"
        case .duplicate: "重复照片"
        }
    }
}

/// 一组相似 / 重复照片，以及默认（可手动修改）的保留项。
struct PhotoGroup: Identifiable, Equatable {
    /// 取首个成员的 id，同一份缓存下分组结果稳定。
    let id: String
    var members: [AnalysisRecord]
    var keepID: String

    var removable: [AnalysisRecord] {
        members.filter { $0.id != keepID }
    }

    var reclaimableBytes: Int64 {
        removable.reduce(0) { $0 + $1.fileSize }
    }

    var plan: MergePlan {
        MergePlan(keepID: keepID, removeIDs: removable.map(\.id))
    }

    static func make(from members: [AnalysisRecord], kind: GroupKind) -> PhotoGroup? {
        guard members.count >= 2 else { return nil }
        let keep: String? = switch kind {
        case .similar: BestPhotoPicker.pickBest(from: members)
        case .duplicate: BestPhotoPicker.pickOriginal(from: members)
        }
        guard let keep else { return nil }
        return PhotoGroup(id: members[0].id, members: members, keepID: keep)
    }
}
