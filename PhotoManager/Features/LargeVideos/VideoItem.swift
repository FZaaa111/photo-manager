import Photos

struct VideoItem: Identifiable, Hashable, Sendable {
    /// PHAsset.localIdentifier
    let id: String
    let duration: TimeInterval
    let fileSize: Int64
    let creationDate: Date?
}

enum VideoScanner {
    /// 扫描全部视频并按体积从大到小排序。可能较慢，请在后台线程调用。
    static func scan() -> [VideoItem] {
        let result = PHAsset.fetchAssets(with: .video, options: nil)
        var items: [VideoItem] = []
        items.reserveCapacity(result.count)

        result.enumerateObjects { asset, _, _ in
            items.append(
                VideoItem(
                    id: asset.localIdentifier,
                    duration: asset.duration,
                    fileSize: fileSize(of: asset),
                    creationDate: asset.creationDate
                )
            )
        }
        return sortedBySizeDescending(items)
    }

    static func sortedBySizeDescending(_ items: [VideoItem]) -> [VideoItem] {
        items.sorted { $0.fileSize > $1.fileSize }
    }

    /// PhotoKit 没有公开的文件大小 API，这里通过 KVC 读取 PHAssetResource 的 "fileSize"。
    /// 这是业界常用但未文档化的做法；读取失败时返回 0。
    private static func fileSize(of asset: PHAsset) -> Int64 {
        let resources = PHAssetResource.assetResources(for: asset)
        let video = resources.first { $0.type == .video || $0.type == .fullSizeVideo }
        guard let video,
              let number = video.value(forKey: "fileSize") as? NSNumber
        else { return 0 }
        return number.int64Value
    }
}
