import CryptoKit
import Foundation
import Photos

/// 流式读取资源原始数据并计算 SHA256，避免把整张原图读入内存。
enum ContentHasher {
    private final class HasherBox: @unchecked Sendable {
        var hasher = SHA256()
    }

    /// 资源不在本机（iCloud 优化存储）或读取失败时返回 nil，不会触发网络下载。
    static func sha256(forLocalIdentifier identifier: String) async -> String? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject else {
            return nil
        }
        let resources = PHAssetResource.assetResources(for: asset)
        guard let resource = resources.first(where: { $0.type == .photo })
                ?? resources.first(where: { $0.type == .fullSizePhoto })
        else { return nil }

        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = false

        let box = HasherBox()
        let succeeded: Bool = await withCheckedContinuation { continuation in
            PHAssetResourceManager.default().requestData(
                for: resource,
                options: options,
                dataReceivedHandler: { chunk in
                    box.hasher.update(data: chunk)
                },
                completionHandler: { error in
                    continuation.resume(returning: error == nil)
                }
            )
        }
        guard succeeded else { return nil }
        return box.hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
