import Foundation

enum SimilarityLevel: String, CaseIterable, Identifiable, Sendable {
    case strict
    case standard
    case loose

    var id: String { rawValue }

    var title: String {
        switch self {
        case .strict: "严格"
        case .standard: "标准"
        case .loose: "宽松"
        }
    }

    /// dHash 汉明距离上限（粗筛）。
    var maxHashDistance: Int {
        switch self {
        case .strict: 6
        case .standard: 10
        case .loose: 16
        }
    }

    /// Vision 特征向量距离上限（精筛）。数值需在真机上用实际相册调参。
    var maxFeatureDistance: Float {
        switch self {
        case .strict: 0.25
        case .standard: 0.45
        case .loose: 0.70
        }
    }

    /// 只在拍摄时间相近的照片之间比较，避免 O(n²)。
    var timeWindow: TimeInterval {
        switch self {
        case .strict: 30
        case .standard: 120
        case .loose: 600
        }
    }
}

/// 把视觉相近的照片聚成组。纯算法，距离函数由调用方注入。
enum SimilarGrouper {
    /// 单张照片最多与其后多少张邻居比较，限制极端连拍场景的开销。
    static let maxNeighbors = 60

    /// 按拍摄时间排序后的候选（没有 dHash 又不属于连拍的记录无法作为候选）。
    private static func sortedCandidates(_ records: [AnalysisRecord]) -> [AnalysisRecord] {
        records
            .filter { $0.dHash != nil || $0.burstIdentifier != nil }
            .sorted {
                let l = $0.creationDate ?? .distantPast
                let r = $1.creationDate ?? .distantPast
                return l == r ? $0.id < $1.id : l < r
            }
    }

    /// 通过粗筛（时间窗口 + 连拍 / dHash）的候选对，返回 candidates 中的下标。
    private static func coarsePairs(_ candidates: [AnalysisRecord], level: SimilarityLevel) -> [(Int, Int)] {
        var pairs: [(Int, Int)] = []
        for i in 0..<candidates.count {
            let a = candidates[i]
            var j = i + 1
            while j < candidates.count, j - i <= maxNeighbors {
                let b = candidates[j]
                if let da = a.creationDate, let db = b.creationDate,
                   db.timeIntervalSince(da) > level.timeWindow {
                    break
                }
                if passesCoarse(a, b, level: level) {
                    pairs.append((i, j))
                }
                j += 1
            }
        }
        return pairs
    }

    /// 参与了至少一个粗筛候选对的资源 id。只需要对这些资源计算（较贵的）特征向量。
    static func coarseCandidateIDs(_ records: [AnalysisRecord], level: SimilarityLevel) -> Set<String> {
        let candidates = sortedCandidates(records)
        var ids = Set<String>()
        for (i, j) in coarsePairs(candidates, level: level) {
            ids.insert(candidates[i].id)
            ids.insert(candidates[j].id)
        }
        return ids
    }

    /// - Parameters:
    ///   - distance: 两个归档特征向量之间的距离；无法计算时返回 nil。
    /// - Returns: 每组的资源 id（至少 2 个），组内按拍摄时间升序，组间按首张时间升序。
    static func group(
        _ records: [AnalysisRecord],
        level: SimilarityLevel,
        distance: (Data, Data) -> Float?
    ) -> [[String]] {
        let candidates = sortedCandidates(records)
        guard candidates.count >= 2 else { return [] }

        var uf = UnionFind(count: candidates.count)
        for (i, j) in coarsePairs(candidates, level: level)
        where passesFine(candidates[i], candidates[j], level: level, distance: distance) {
            uf.union(i, j)
        }

        var buckets: [Int: [Int]] = [:]
        for i in 0..<candidates.count {
            buckets[uf.find(i), default: []].append(i)
        }
        // candidates 已按时间排序，索引升序即时间升序。
        return buckets.values
            .map { $0.sorted() }
            .filter { $0.count >= 2 }
            .sorted { $0[0] < $1[0] }
            .map { indices in indices.map { candidates[$0].id } }
    }

    private static func hashDistance(_ a: AnalysisRecord, _ b: AnalysisRecord) -> Int? {
        guard let ha = a.dHash, let hb = b.dHash else { return nil }
        return PerceptualHash.hammingDistance(ha, hb)
    }

    private static func sameBurst(_ a: AnalysisRecord, _ b: AnalysisRecord) -> Bool {
        a.burstIdentifier != nil && a.burstIdentifier == b.burstIdentifier
    }

    /// 粗筛：同一连拍，或 dHash 足够接近。
    private static func passesCoarse(_ a: AnalysisRecord, _ b: AnalysisRecord, level: SimilarityLevel) -> Bool {
        sameBurst(a, b) || (hashDistance(a, b) ?? Int.max) <= level.maxHashDistance
    }

    /// 精筛：两边都有特征向量时以特征距离为准；否则只接受哈希非常接近的情况。
    private static func passesFine(
        _ a: AnalysisRecord,
        _ b: AnalysisRecord,
        level: SimilarityLevel,
        distance: (Data, Data) -> Float?
    ) -> Bool {
        if let fa = a.featurePrint, let fb = b.featurePrint, let d = distance(fa, fb) {
            return d <= level.maxFeatureDistance
        }
        if let hd = hashDistance(a, b) {
            return hd <= SimilarityLevel.strict.maxHashDistance
        }
        return false
    }
}

struct UnionFind {
    private var parent: [Int]
    private var rank: [Int]

    init(count: Int) {
        parent = Array(0..<count)
        rank = Array(repeating: 0, count: count)
    }

    mutating func find(_ x: Int) -> Int {
        var root = x
        while parent[root] != root { root = parent[root] }
        var node = x
        while parent[node] != root {
            let next = parent[node]
            parent[node] = root
            node = next
        }
        return root
    }

    mutating func union(_ a: Int, _ b: Int) {
        let ra = find(a)
        let rb = find(b)
        guard ra != rb else { return }
        if rank[ra] < rank[rb] {
            parent[ra] = rb
        } else if rank[ra] > rank[rb] {
            parent[rb] = ra
        } else {
            parent[rb] = ra
            rank[ra] += 1
        }
    }
}
