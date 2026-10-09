import Foundation
import SwiftData

/// 扫描结果缓存。以 PHAsset.localIdentifier 为键，modificationDate 变化时失效。
@Model
final class AssetRecord {
    @Attribute(.unique) var localIdentifier: String
    var modificationDate: Date?
    var creationDate: Date?
    var pixelWidth: Int
    var pixelHeight: Int
    var fileSize: Int64
    var burstIdentifier: String?
    var isFavorite: Bool
    var isScreenshot: Bool

    var sharpness: Double?
    /// dHash 的位模式（UInt64 → Int64），SwiftData 不直接支持 UInt64。
    var dHashBits: Int64?
    var featurePrint: Data?
    var contentHash: String?
    var faceQuality: Double?

    init(
        localIdentifier: String,
        modificationDate: Date?,
        creationDate: Date?,
        pixelWidth: Int,
        pixelHeight: Int,
        burstIdentifier: String?,
        isFavorite: Bool,
        isScreenshot: Bool
    ) {
        self.localIdentifier = localIdentifier
        self.modificationDate = modificationDate
        self.creationDate = creationDate
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.fileSize = 0
        self.burstIdentifier = burstIdentifier
        self.isFavorite = isFavorite
        self.isScreenshot = isScreenshot
    }

    /// 资源被编辑 / 替换后，清空所有派生数据。
    func resetAnalysis() {
        fileSize = 0
        sharpness = nil
        dHashBits = nil
        featurePrint = nil
        contentHash = nil
        faceQuality = nil
    }

    var snapshot: AnalysisRecord {
        AnalysisRecord(
            id: localIdentifier,
            creationDate: creationDate,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            fileSize: fileSize,
            burstIdentifier: burstIdentifier,
            isFavorite: isFavorite,
            isScreenshot: isScreenshot,
            sharpness: sharpness,
            dHash: dHashBits.map { UInt64(bitPattern: $0) },
            featurePrint: featurePrint,
            contentHash: contentHash,
            faceQuality: faceQuality
        )
    }
}

/// 用户选择"忽略"的资源（例如被误判为模糊的截图）。
@Model
final class IgnoredAsset {
    @Attribute(.unique) var localIdentifier: String
    var reason: String
    var createdAt: Date

    init(localIdentifier: String, reason: String, createdAt: Date = .now) {
        self.localIdentifier = localIdentifier
        self.reason = reason
        self.createdAt = createdAt
    }
}
