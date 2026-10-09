import Foundation

struct AlbumSummary: Identifiable, Equatable, Sendable {
    /// PHAssetCollection.localIdentifier
    let id: String
    let title: String
    let assetCount: Int
}

/// 清理建议，按潜在收益排序后展示在首页。
enum HealthSuggestion: Equatable, Sendable {
    case largeVideos(count: Int, bytes: Int64)
    case blurry(count: Int)
    case screenshots(count: Int)
    case screenRecordings(count: Int)
    case bursts(count: Int)
    case emptyAlbums(count: Int)

    var title: String {
        switch self {
        case .largeVideos(let count, let bytes):
            "\(count) 个大视频，共 \(Formatters.fileSize(bytes))"
        case .blurry(let count):
            "约 \(count) 张照片可能模糊"
        case .screenshots(let count):
            "\(count) 张截图"
        case .screenRecordings(let count):
            "\(count) 个屏幕录制"
        case .bursts(let count):
            "\(count) 张连拍照片"
        case .emptyAlbums(let count):
            "\(count) 个空相册"
        }
    }

    var systemImage: String {
        switch self {
        case .largeVideos: "video"
        case .blurry: "camera.metering.unknown"
        case .screenshots: "camera.viewfinder"
        case .screenRecordings: "record.circle"
        case .bursts: "square.stack.3d.down.right"
        case .emptyAlbums: "rectangle.stack"
        }
    }
}

/// 相册健康检查结果。纯值类型：采集由 `AlbumHealthService` 完成，建议生成在这里，便于测试。
struct AlbumHealthReport: Equatable, Sendable {
    var photoCount = 0
    var videoCount = 0

    var screenshotCount = 0
    var screenRecordingCount = 0
    var burstCount = 0
    var livePhotoCount = 0
    var panoramaCount = 0

    var emptyAlbums: [AlbumSummary] = []

    /// 达到大视频阈值（见 `AlbumHealthService.largeVideoThreshold`）的视频。
    var largeVideoCount = 0
    var largeVideoBytes: Int64 = 0

    /// 来自扫描缓存：已分析的照片数与其中疑似模糊的数量。
    var analyzedPhotoCount = 0
    var blurryCount = 0

    /// 已分析比例 0...1。
    var analyzedFraction: Double {
        photoCount > 0 ? min(1, Double(analyzedPhotoCount) / Double(photoCount)) : 0
    }

    var suggestions: [HealthSuggestion] {
        var result: [HealthSuggestion] = []
        if largeVideoCount > 0 {
            result.append(.largeVideos(count: largeVideoCount, bytes: largeVideoBytes))
        }
        if blurryCount > 0 {
            result.append(.blurry(count: blurryCount))
        }
        if screenshotCount >= 50 {
            result.append(.screenshots(count: screenshotCount))
        }
        if screenRecordingCount >= 5 {
            result.append(.screenRecordings(count: screenRecordingCount))
        }
        if burstCount >= 20 {
            result.append(.bursts(count: burstCount))
        }
        if !emptyAlbums.isEmpty {
            result.append(.emptyAlbums(count: emptyAlbums.count))
        }
        return result
    }
}
