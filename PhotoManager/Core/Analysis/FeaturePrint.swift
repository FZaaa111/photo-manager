import CoreGraphics
import Foundation
import Vision

/// Vision 特征向量与人脸质量的薄封装。
enum FeaturePrint {
    /// 计算图像特征向量并归档为 Data，便于写入缓存。
    static func archivedFeaturePrint(for cgImage: CGImage) -> Data? {
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            guard let observation = request.results?.first else { return nil }
            return try NSKeyedArchiver.archivedData(withRootObject: observation, requiringSecureCoding: true)
        } catch {
            return nil
        }
    }

    static func distance(_ a: Data, _ b: Data) -> Float? {
        guard let oa = try? NSKeyedUnarchiver.unarchivedObject(ofClass: VNFeaturePrintObservation.self, from: a),
              let ob = try? NSKeyedUnarchiver.unarchivedObject(ofClass: VNFeaturePrintObservation.self, from: b)
        else { return nil }
        var value: Float = 0
        do {
            try oa.computeDistance(&value, to: ob)
            return value
        } catch {
            return nil
        }
    }

    /// 图中最大人脸的质量（0...1）；没有人脸返回 nil。
    static func faceQuality(for cgImage: CGImage) -> Double? {
        let request = VNDetectFaceCaptureQualityRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            let faces = request.results ?? []
            guard let best = faces.max(by: { $0.boundingBox.area < $1.boundingBox.area }),
                  let quality = best.faceCaptureQuality
            else { return nil }
            return Double(quality)
        } catch {
            return nil
        }
    }
}

/// 缓存反归档后的特征向量，避免成组比较时对同一张照片重复反归档。
/// 非线程安全：每次分组计算创建一个实例，只在单个线程使用。
final class FeatureDistanceCache {
    private var cache: [Data: VNFeaturePrintObservation] = [:]

    func distance(_ a: Data, _ b: Data) -> Float? {
        guard let oa = observation(a), let ob = observation(b) else { return nil }
        var value: Float = 0
        do {
            try oa.computeDistance(&value, to: ob)
            return value
        } catch {
            return nil
        }
    }

    private func observation(_ data: Data) -> VNFeaturePrintObservation? {
        if let cached = cache[data] { return cached }
        guard let obs = try? NSKeyedUnarchiver.unarchivedObject(ofClass: VNFeaturePrintObservation.self, from: data) else {
            return nil
        }
        cache[data] = obs
        return obs
    }
}

private extension CGRect {
    var area: CGFloat { width * height }
}
