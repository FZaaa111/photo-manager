import Photos
import Observation

enum PhotoAuthorization: Equatable {
    case notDetermined
    case denied
    case limited
    case authorized
}

/// 封装 PhotoKit 的授权状态与基础统计。
@MainActor
@Observable
final class PhotoLibraryService {
    private(set) var authorization: PhotoAuthorization

    init() {
        authorization = Self.map(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    func requestAuthorization() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        authorization = Self.map(status)
    }

    func photoCount() -> Int {
        PHAsset.fetchAssets(with: .image, options: nil).count
    }

    func videoCount() -> Int {
        PHAsset.fetchAssets(with: .video, options: nil).count
    }

    nonisolated static func map(_ status: PHAuthorizationStatus) -> PhotoAuthorization {
        switch status {
        case .notDetermined: .notDetermined
        case .limited: .limited
        case .authorized: .authorized
        case .denied, .restricted: .denied
        @unknown default: .denied
        }
    }
}
