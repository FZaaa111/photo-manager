import Photos

/// 一次"合并"：保留 keepID，删除 removeIDs。
struct MergePlan: Sendable, Equatable {
    let keepID: String
    let removeIDs: [String]
    /// 相似照片合并时，把被删项的收藏状态与所属用户相册并入保留项；
    /// 重复照片（内容完全相同）同样适用，因此默认开启。
    var mergeMetadata: Bool = true
}

/// 删除 / 合并相册资源。系统会弹出确认框，被删除的项目进入"最近删除"，30 天内可恢复。
enum PhotoDeletionService {
    static func delete(localIdentifiers: [String]) async throws {
        guard !localIdentifiers.isEmpty else { return }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: localIdentifiers, options: nil)
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets)
        }
    }

    /// 在同一次 performChanges 中完成"并入元数据 + 删除"，用户取消系统确认框时整体不生效。
    static func merge(_ plans: [MergePlan]) async throws {
        let plans = plans.filter { !$0.removeIDs.isEmpty }
        guard !plans.isEmpty else { return }

        let allIDs = plans.flatMap { [$0.keepID] + $0.removeIDs }
        var assets: [String: PHAsset] = [:]
        PHAsset.fetchAssets(withLocalIdentifiers: allIDs, options: nil)
            .enumerateObjects { asset, _, _ in assets[asset.localIdentifier] = asset }

        // 先在变更块外面算好需要加入哪些相册。
        var albumAdds: [(album: PHAssetCollection, keep: PHAsset)] = []
        var favoriteTargets: [PHAsset] = []
        for plan in plans where plan.mergeMetadata {
            guard let keep = assets[plan.keepID] else { continue }
            let removed = plan.removeIDs.compactMap { assets[$0] }

            if !keep.isFavorite, removed.contains(where: \.isFavorite) {
                favoriteTargets.append(keep)
            }

            let keepAlbums = Set(albumIDs(containing: keep))
            var seen = keepAlbums
            for asset in removed {
                for album in albums(containing: asset) where !seen.contains(album.localIdentifier) {
                    seen.insert(album.localIdentifier)
                    albumAdds.append((album, keep))
                }
            }
        }

        let toDelete = plans.flatMap(\.removeIDs).compactMap { assets[$0] }
        guard !toDelete.isEmpty else { return }

        try await PHPhotoLibrary.shared().performChanges {
            for asset in favoriteTargets {
                PHAssetChangeRequest(for: asset).isFavorite = true
            }
            for (album, keep) in albumAdds {
                PHAssetCollectionChangeRequest(for: album)?.addAssets([keep] as NSArray)
            }
            PHAssetChangeRequest.deleteAssets(toDelete as NSArray)
        }
    }

    /// 用户在系统确认框点了"取消"。
    static func isUserCancelled(_ error: Error) -> Bool {
        (error as? PHPhotosError)?.code == .userCancelled
    }

    // MARK: -

    private static func albums(containing asset: PHAsset) -> [PHAssetCollection] {
        var result: [PHAssetCollection] = []
        PHAssetCollection.fetchAssetCollectionsContaining(asset, with: .album, options: nil)
            .enumerateObjects { collection, _, _ in result.append(collection) }
        return result
    }

    private static func albumIDs(containing asset: PHAsset) -> [String] {
        albums(containing: asset).map(\.localIdentifier)
    }
}
