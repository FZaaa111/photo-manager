import Foundation

/// 一张照片的分析结果快照。与 PhotoKit / SwiftData 解耦，便于纯算法测试。
struct AnalysisRecord: Identifiable, Hashable, Sendable {
    /// PHAsset.localIdentifier
    let id: String
    var creationDate: Date?
    var pixelWidth: Int = 0
    var pixelHeight: Int = 0
    var fileSize: Int64 = 0
    var burstIdentifier: String?
    var isFavorite: Bool = false
    var isScreenshot: Bool = false

    /// 拉普拉斯方差，越大越清晰；nil 表示尚未分析。
    var sharpness: Double?
    /// 64 位 dHash；nil 表示尚未分析。
    var dHash: UInt64?
    /// 归档后的 VNFeaturePrintObservation。
    var featurePrint: Data?
    /// 原始文件内容 SHA256（十六进制）。
    var contentHash: String?
    /// 0...1 的人脸质量；nil 表示无人脸或未分析。
    var faceQuality: Double?

    var pixelCount: Int { pixelWidth * pixelHeight }
}
