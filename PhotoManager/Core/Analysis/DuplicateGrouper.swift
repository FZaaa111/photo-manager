import Foundation

/// 重复（内容完全相同）照片分组。
enum DuplicateGrouper {
    /// 第一阶段：用文件大小 + 像素尺寸预分桶。只有同桶且数量 ≥ 2 的资源才值得读取内容算哈希。
    static func candidateBuckets(_ records: [AnalysisRecord]) -> [[AnalysisRecord]] {
        var buckets: [String: [AnalysisRecord]] = [:]
        for record in records where record.fileSize > 0 {
            let key = "\(record.fileSize)-\(record.pixelWidth)x\(record.pixelHeight)"
            buckets[key, default: []].append(record)
        }
        return buckets.values.filter { $0.count >= 2 }
    }

    /// 第二阶段：按内容哈希精确分组。没有 contentHash 的记录被忽略。
    /// - Returns: 每组资源 id（≥ 2），组内按拍摄时间升序，组间按首个 id 排序以保证稳定。
    static func group(_ records: [AnalysisRecord]) -> [[String]] {
        var byHash: [String: [AnalysisRecord]] = [:]
        for record in records {
            guard let hash = record.contentHash else { continue }
            byHash[hash, default: []].append(record)
        }
        return byHash.values
            .filter { $0.count >= 2 }
            .map { members in
                members
                    .sorted {
                        let l = $0.creationDate ?? .distantFuture
                        let r = $1.creationDate ?? .distantFuture
                        return l == r ? $0.id < $1.id : l < r
                    }
                    .map(\.id)
            }
            .sorted { ($0.first ?? "") < ($1.first ?? "") }
    }
}
