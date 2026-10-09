import Photos

/// 采集相册健康检查所需的统计数据。所有方法都应在后台调用。
enum AlbumHealthService {
    /// 超过该体积的视频计入"大视频"。
    static let largeVideoThreshold: Int64 = 100_000_000

    static func load(store: RecordStore) async -> AlbumHealthReport {
        var report = AlbumHealthReport()

        report.photoCount = PHAsset.fetchAssets(with: .image, options: nil).count
        report.videoCount = PHAsset.fetchAssets(with: .video, options: nil).count

        report.screenshotCount = smartAlbumCount(.smartAlbumScreenshots)
        report.screenRecordingCount = smartAlbumCount(.smartAlbumScreenRecordings)
        report.burstCount = smartAlbumCount(.smartAlbumBursts)
        report.livePhotoCount = smartAlbumCount(.smartAlbumLivePhotos)
        report.panoramaCount = smartAlbumCount(.smartAlbumPanoramas)

        report.emptyAlbums = userAlbums().filter { $0.assetCount == 0 }

        let largeVideos = VideoScanner.scan().filter { $0.fileSize >= largeVideoThreshold }
        report.largeVideoCount = largeVideos.count
        report.largeVideoBytes = largeVideos.reduce(0) { $0 + $1.fileSize }

        if let cached = try? await store.allRecords(), let ignored = try? await store.ignoredIDs() {
            let analyzed = cached.filter { $0.sharpness != nil }
            report.analyzedPhotoCount = analyzed.count
            report.blurryCount = BlurryFilter.blurry(
                from: analyzed,
                threshold: BlurryFilter.defaultThreshold,
                ignored: ignored,
                includeScreenshots: false
            ).count
        }
        return report
    }

    /// 删除（空）相册本身，不会删除其中的照片。
    static func deleteAlbums(localIdentifiers: [String]) async throws {
        guard !localIdentifiers.isEmpty else { return }
        let collections = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: localIdentifiers, options: nil)
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCollectionChangeRequest.deleteAssetCollections(collections)
        }
    }

    static func userAlbums() -> [AlbumSummary] {
        var result: [AlbumSummary] = []
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: nil)
        collections.enumerateObjects { collection, _, _ in
            let count = PHAsset.fetchAssets(in: collection, options: nil).count
            result.append(
                AlbumSummary(
                    id: collection.localIdentifier,
                    title: collection.localizedTitle ?? "未命名相册",
                    assetCount: count
                )
            )
        }
        return result
    }

    private static func smartAlbumCount(_ subtype: PHAssetCollectionSubtype) -> Int {
        let collections = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: subtype, options: nil)
        guard let collection = collections.firstObject else { return 0 }
        return PHAsset.fetchAssets(in: collection, options: nil).count
    }
}
