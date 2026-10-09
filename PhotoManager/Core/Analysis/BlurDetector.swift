import Foundation

/// 基于拉普拉斯方差的清晰度评估。
///
/// 局限：纯色/低纹理图片（截图、白墙）方差天然很低，会被误判为模糊，
/// 因此界面上需要提供阈值调节与"忽略"。
enum BlurDetector {
    /// 分析时统一使用的长边像素，保证不同来源的分数可比。
    static let analysisSide = 256

    /// 返回清晰度分数：3×3 拉普拉斯响应的方差，值越大越清晰。
    static func sharpness(of image: GrayImage) -> Double {
        let w = image.width
        let h = image.height
        guard w >= 3, h >= 3 else { return 0 }

        var sum = 0.0
        var sumSquares = 0.0
        var count = 0.0
        let p = image.pixels

        for y in 1..<(h - 1) {
            for x in 1..<(w - 1) {
                let i = y * w + x
                let response = Double(p[i - w] + p[i + w] + p[i - 1] + p[i + 1] - 4 * p[i])
                sum += response
                sumSquares += response * response
                count += 1
            }
        }
        let mean = sum / count
        return max(0, sumSquares / count - mean * mean)
    }
}
