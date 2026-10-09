import Foundation

/// 在一组照片里挑出应当保留的那张。
enum BestPhotoPicker {
    /// 相似照片：清晰度 + 人脸质量 + 收藏 + 分辨率 加权。
    static func pickBest(from group: [AnalysisRecord]) -> String? {
        guard !group.isEmpty else { return nil }
        let maxPixels = max(1, group.map(\.pixelCount).max() ?? 1)

        func score(_ r: AnalysisRecord) -> Double {
            let sharp = min((r.sharpness ?? 0) / 300.0, 1.0)
            let face = r.faceQuality ?? 0
            let favorite = r.isFavorite ? 1.0 : 0.0
            let resolution = Double(r.pixelCount) / Double(maxPixels)
            return sharp * 0.40 + face * 0.30 + favorite * 0.15 + resolution * 0.15
        }

        return group
            .sorted {
                let ls = score($0), rs = score($1)
                if ls != rs { return ls > rs }
                return $0.id < $1.id
            }
            .first?.id
    }

    /// 重复照片：内容相同，保留收藏的；其次最早创建的；再其次分辨率最高的。
    static func pickOriginal(from group: [AnalysisRecord]) -> String? {
        group
            .sorted {
                if $0.isFavorite != $1.isFavorite { return $0.isFavorite }
                let l = $0.creationDate ?? .distantFuture
                let r = $1.creationDate ?? .distantFuture
                if l != r { return l < r }
                if $0.pixelCount != $1.pixelCount { return $0.pixelCount > $1.pixelCount }
                return $0.id < $1.id
            }
            .first?.id
    }
}
