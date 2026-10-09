import Foundation

/// 差值哈希（dHash）：缩放到 9×8，逐行比较相邻像素，得到 64 位指纹。
enum PerceptualHash {
    static func dHash(of image: GrayImage) -> UInt64 {
        let small = image.resized(width: 9, height: 8)
        var hash: UInt64 = 0
        var bit: UInt64 = 0
        for y in 0..<8 {
            for x in 0..<8 {
                if small[x, y] < small[x + 1, y] {
                    hash |= (1 << bit)
                }
                bit += 1
            }
        }
        return hash
    }

    static func hammingDistance(_ a: UInt64, _ b: UInt64) -> Int {
        (a ^ b).nonzeroBitCount
    }
}
