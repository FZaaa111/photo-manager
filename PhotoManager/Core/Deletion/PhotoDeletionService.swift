import Photos

/// 删除相册资源。系统会弹出确认框，被删除的项目进入"最近删除"，30 天内可恢复。
enum PhotoDeletionService {
    static func delete(localIdentifiers: [String]) async throws {
        guard !localIdentifiers.isEmpty else { return }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: localIdentifiers, options: nil)
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets)
        }
    }
}
