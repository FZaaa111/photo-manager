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
                    fileSize: AssetResourceInfo.fileSize(of: asset, types: [.video, .fullSizeVideo]),
                    creationDate: asset.creationDate
                )
            )
        }
        return sortedBySizeDescending(items)
    }

    static func sortedBySizeDescending(_ items: [VideoItem]) -> [VideoItem] {
        items.sorted { $0.fileSize > $1.fileSize }
    }
}
