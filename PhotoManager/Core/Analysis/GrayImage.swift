import CoreGraphics

/// 8 位灰度图（像素值 0...255，以 Float 保存）。纯值类型，不依赖 PhotoKit。
struct GrayImage: Sendable, Equatable {
    let width: Int
    let height: Int
    /// 行优先，count == width * height。
    let pixels: [Float]

    init(width: Int, height: Int, pixels: [Float]) {
        precondition(pixels.count == width * height, "pixels.count 必须等于 width * height")
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    subscript(x: Int, y: Int) -> Float {
        pixels[y * width + x]
    }

    /// 盒式滤波缩放（面积平均），用于 dHash 与统一分析尺度。
    func resized(width newWidth: Int, height newHeight: Int) -> GrayImage {
        precondition(newWidth > 0 && newHeight > 0)
        var output = [Float](repeating: 0, count: newWidth * newHeight)
        for y in 0..<newHeight {
            let y0 = min(y * height / newHeight, height - 1)
            let y1 = min(max(y0 + 1, (y + 1) * height / newHeight), height)
            for x in 0..<newWidth {
                let x0 = min(x * width / newWidth, width - 1)
                let x1 = min(max(x0 + 1, (x + 1) * width / newWidth), width)
                var sum: Float = 0
                for yy in y0..<y1 {
                    for xx in x0..<x1 {
                        sum += pixels[yy * width + xx]
                    }
                }
                output[y * newWidth + x] = sum / Float((y1 - y0) * (x1 - x0))
            }
        }
        return GrayImage(width: newWidth, height: newHeight, pixels: output)
    }

    /// 把 CGImage 绘制到灰度位图，长边缩放到 `maxSide`（不放大）。
    static func make(from cgImage: CGImage, maxSide: Int = 256) -> GrayImage? {
        let srcW = cgImage.width
        let srcH = cgImage.height
        guard srcW > 0, srcH > 0 else { return nil }

        let scale = min(1.0, Double(maxSide) / Double(max(srcW, srcH)))
        let w = max(1, Int((Double(srcW) * scale).rounded()))
        let h = max(1, Int((Double(srcH) * scale).rounded()))

        var bytes = [UInt8](repeating: 0, count: w * h)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: w,
                height: h,
                bitsPerComponent: 8,
                bytesPerRow: w,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return false }
            context.interpolationQuality = .medium
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard drawn else { return nil }
        return GrayImage(width: w, height: h, pixels: bytes.map { Float($0) })
    }
}
