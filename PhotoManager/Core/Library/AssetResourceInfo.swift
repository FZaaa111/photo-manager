import Photos

enum AssetResourceInfo {
    /// PhotoKit 没有公开的文件大小 API，这里通过 KVC 读取 PHAssetResource 的 "fileSize"。
    /// 这是业界常用但未文档化的做法；读取失败时返回 0。
    static func fileSize(of asset: PHAsset, types: [PHAssetResourceType]) -> Int64 {
        let resources = PHAssetResource.assetResources(for: asset)
        for type in types {
            if let resource = resources.first(where: { $0.type == type }),
               let number = resource.value(forKey: "fileSize") as? NSNumber {
                return number.int64Value
            }
        }
        return 0
    }

    /// 照片原图大小。
    static func photoFileSize(of asset: PHAsset) -> Int64 {
        fileSize(of: asset, types: [.photo, .fullSizePhoto])
    }
}
