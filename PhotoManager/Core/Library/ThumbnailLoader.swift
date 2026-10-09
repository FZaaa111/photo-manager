import Photos
import SwiftUI
import UIKit

/// 按 localIdentifier 异步加载相册缩略图。
enum ThumbnailLoader {
    private static let manager = PHCachingImageManager()

    static func image(for localIdentifier: String, targetSize: CGSize) async -> UIImage? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil).firstObject else {
            return nil
        }

        let options = PHImageRequestOptions()
        // highQualityFormat 保证回调只触发一次，避免 continuation 被重复 resume。
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = false

        return await withCheckedContinuation { continuation in
            manager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}

/// 方形缩略图视图。
struct AssetThumbnailView: View {
    let localIdentifier: String
    var side: CGFloat = 64

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Rectangle().fill(.quaternary)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .task(id: localIdentifier) {
            let pixels = side * displayScale
            image = await ThumbnailLoader.image(
                for: localIdentifier,
                targetSize: CGSize(width: pixels, height: pixels)
            )
        }
    }
}
