import XCTest
@testable import PhotoManager

// MARK: - 测试辅助

private func checkerboard(size: Int = 64, cell: Int = 8) -> GrayImage {
    var pixels = [Float](repeating: 0, count: size * size)
    for y in 0..<size {
        for x in 0..<size {
            pixels[y * size + x] = ((x / cell + y / cell) % 2 == 0) ? 0 : 255
        }
    }
    return GrayImage(width: size, height: size, pixels: pixels)
}

private func boxBlur(_ image: GrayImage, passes: Int) -> GrayImage {
    var current = image
    for _ in 0..<passes {
        var out = current.pixels
        let w = current.width, h = current.height
        for y in 0..<h {
            for x in 0..<w {
                var sum: Float = 0
                var n: Float = 0
                for dy in -2...2 {
                    for dx in -2...2 {
                        let xx = x + dx, yy = y + dy
                        guard xx >= 0, xx < w, yy >= 0, yy < h else { continue }
                        sum += current[xx, yy]
                        n += 1
                    }
                }
                out[y * w + x] = sum / n
            }
        }
        current = GrayImage(width: w, height: h, pixels: out)
    }
    return current
}

private func gradient(ascending: Bool, scale: Float = 1, offset: Float = 0) -> GrayImage {
    let w = 90, h = 80
    var pixels = [Float](repeating: 0, count: w * h)
    for y in 0..<h {
        for x in 0..<w {
            let v = ascending ? Float(x) : Float(w - 1 - x)
            pixels[y * w + x] = v * 2 * scale + offset
        }
    }
    return GrayImage(width: w, height: h, pixels: pixels)
}

// MARK: - GrayImage / BlurDetector

final class BlurDetectorTests: XCTestCase {
    func testSharpImageScoresHigherThanBlurredImage() {
        let sharp = checkerboard()
        let blurred = boxBlur(sharp, passes: 3)
        XCTAssertGreaterThan(BlurDetector.sharpness(of: sharp), BlurDetector.sharpness(of: blurred))
    }

    func testFlatImageScoresZero() {
        let flat = GrayImage(width: 32, height: 32, pixels: Array(repeating: 128, count: 32 * 32))
        XCTAssertEqual(BlurDetector.sharpness(of: flat), 0, accuracy: 0.0001)
    }

    func testTinyImageScoresZero() {
        let tiny = GrayImage(width: 2, height: 2, pixels: [0, 255, 255, 0])
        XCTAssertEqual(BlurDetector.sharpness(of: tiny), 0)
    }

    func testResizedPreservesAverageOfUniformImage() {
        let image = GrayImage(width: 40, height: 40, pixels: Array(repeating: 100, count: 1600))
        let small = image.resized(width: 9, height: 8)
        XCTAssertEqual(small.width, 9)
        XCTAssertEqual(small.height, 8)
        XCTAssertTrue(small.pixels.allSatisfy { abs($0 - 100) < 0.001 })
    }
}

// MARK: - PerceptualHash

final class PerceptualHashTests: XCTestCase {
    func testIdenticalImagesHaveZeroDistance() {
        let a = gradient(ascending: true)
        XCTAssertEqual(PerceptualHash.hammingDistance(PerceptualHash.dHash(of: a), PerceptualHash.dHash(of: a)), 0)
    }

    func testBrightnessAndContrastChangeKeepsHash() {
        let a = gradient(ascending: true)
        let b = gradient(ascending: true, scale: 0.8, offset: 10)
        XCTAssertEqual(PerceptualHash.hammingDistance(PerceptualHash.dHash(of: a), PerceptualHash.dHash(of: b)), 0)
    }

    func testOppositeGradientsAreMaximallyDifferent() {
        let a = gradient(ascending: true)
        let b = gradient(ascending: false)
        XCTAssertEqual(PerceptualHash.hammingDistance(PerceptualHash.dHash(of: a), PerceptualHash.dHash(of: b)), 64)
    }
}

// MARK: - SimilarGrouper

final class SimilarGrouperTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    /// 用单个 Float 编码"特征向量"，距离为差的绝对值。
    private func fp(_ value: Float) -> Data {
        withUnsafeBytes(of: value) { Data($0) }
    }

    private func fakeDistance(_ a: Data, _ b: Data) -> Float? {
        guard a.count == 4, b.count == 4 else { return nil }
        let fa = a.withUnsafeBytes { $0.loadUnaligned(as: Float.self) }
        let fb = b.withUnsafeBytes { $0.loadUnaligned(as: Float.self) }
        return abs(fa - fb)
    }

    private func record(_ id: String, at offset: TimeInterval, hash: UInt64?, feature: Float?, burst: String? = nil) -> AnalysisRecord {
        AnalysisRecord(
            id: id,
            creationDate: t0.addingTimeInterval(offset),
            burstIdentifier: burst,
            dHash: hash,
            featurePrint: feature.map(fp)
        )
    }

    func testGroupsCloseShotsAndSkipsDistantOnes() {
        let records = [
            record("a", at: 0, hash: 0b0000, feature: 0.10),
            record("b", at: 5, hash: 0b0011, feature: 0.15),
            record("far", at: 5000, hash: 0b0000, feature: 0.10),
        ]
        let groups = SimilarGrouper.group(records, level: .standard, distance: fakeDistance)
        XCTAssertEqual(groups, [["a", "b"]])
    }

    func testChainedSimilarityMergesIntoOneGroup() {
        let records = [
            record("a", at: 0, hash: 0, feature: 0.10),
            record("b", at: 10, hash: 0, feature: 0.40),
            record("c", at: 20, hash: 0, feature: 0.70),
        ]
        // a-b 距离 0.30，b-c 距离 0.30，a-c 距离 0.60；标准档上限 0.45，只靠 a-b、b-c 传递。
        let groups = SimilarGrouper.group(records, level: .standard, distance: fakeDistance)
        XCTAssertEqual(groups, [["a", "b", "c"]])
    }

    func testCloseHashButFarFeatureIsNotGrouped() {
        let records = [
            record("a", at: 0, hash: 0, feature: 0.1),
            record("b", at: 1, hash: 0, feature: 0.9),
        ]
        XCTAssertTrue(SimilarGrouper.group(records, level: .loose, distance: fakeDistance).isEmpty)
    }

    func testSameBurstIsCandidateEvenWhenHashesDiffer() {
        let records = [
            record("a", at: 0, hash: 0, feature: 0.10, burst: "B1"),
            record("b", at: 1, hash: UInt64.max, feature: 0.12, burst: "B1"),
        ]
        let groups = SimilarGrouper.group(records, level: .standard, distance: fakeDistance)
        XCTAssertEqual(groups, [["a", "b"]])
    }

    func testRecordsWithoutHashOrBurstAreIgnored() {
        let records = [
            record("a", at: 0, hash: nil, feature: 0.1),
            record("b", at: 1, hash: nil, feature: 0.1),
        ]
        XCTAssertTrue(SimilarGrouper.group(records, level: .loose, distance: fakeDistance).isEmpty)
    }

    func testFallsBackToStrictHashWhenNoFeaturePrint() {
        let near = [
            record("a", at: 0, hash: 0, feature: nil),
            record("b", at: 1, hash: 0b11, feature: nil),
        ]
        XCTAssertEqual(SimilarGrouper.group(near, level: .standard, distance: fakeDistance), [["a", "b"]])

        let notNear = [
            record("a", at: 0, hash: 0, feature: nil),
            record("b", at: 1, hash: 0b1111_1111, feature: nil), // 距离 8：标准档粗筛通过但严格档不过
        ]
        XCTAssertTrue(SimilarGrouper.group(notNear, level: .standard, distance: fakeDistance).isEmpty)
    }
}

// MARK: - DuplicateGrouper / BestPhotoPicker

final class DuplicateGrouperTests: XCTestCase {
    func testCandidateBucketsRequireSameSizeAndDimensions() {
        let records = [
            AnalysisRecord(id: "a", pixelWidth: 100, pixelHeight: 100, fileSize: 500),
            AnalysisRecord(id: "b", pixelWidth: 100, pixelHeight: 100, fileSize: 500),
            AnalysisRecord(id: "c", pixelWidth: 100, pixelHeight: 100, fileSize: 501),
            AnalysisRecord(id: "d", pixelWidth: 200, pixelHeight: 50, fileSize: 500),
            AnalysisRecord(id: "zero1", pixelWidth: 1, pixelHeight: 1, fileSize: 0),
            AnalysisRecord(id: "zero2", pixelWidth: 1, pixelHeight: 1, fileSize: 0),
        ]
        let buckets = DuplicateGrouper.candidateBuckets(records)
        XCTAssertEqual(buckets.count, 1)
        XCTAssertEqual(Set(buckets[0].map(\.id)), ["a", "b"])
    }

    func testGroupsByContentHashAndSortsByDate() {
        let t = Date(timeIntervalSince1970: 1_700_000_000)
        let records = [
            AnalysisRecord(id: "late", creationDate: t.addingTimeInterval(100), contentHash: "h1"),
            AnalysisRecord(id: "early", creationDate: t, contentHash: "h1"),
            AnalysisRecord(id: "solo", creationDate: t, contentHash: "h2"),
            AnalysisRecord(id: "nohash", creationDate: t),
        ]
        XCTAssertEqual(DuplicateGrouper.group(records), [["early", "late"]])
    }
}

final class BestPhotoPickerTests: XCTestCase {
    func testPrefersSharperPhoto() {
        let group = [
            AnalysisRecord(id: "blurry", pixelWidth: 100, pixelHeight: 100, sharpness: 20),
            AnalysisRecord(id: "sharp", pixelWidth: 100, pixelHeight: 100, sharpness: 280),
        ]
        XCTAssertEqual(BestPhotoPicker.pickBest(from: group), "sharp")
    }

    func testFaceQualityCanOutweighSlightSharpnessDifference() {
        let group = [
            AnalysisRecord(id: "eyesClosed", pixelWidth: 100, pixelHeight: 100, sharpness: 250, faceQuality: 0.1),
            AnalysisRecord(id: "smiling", pixelWidth: 100, pixelHeight: 100, sharpness: 220, faceQuality: 0.9),
        ]
        XCTAssertEqual(BestPhotoPicker.pickBest(from: group), "smiling")
    }

    func testEmptyGroupReturnsNil() {
        XCTAssertNil(BestPhotoPicker.pickBest(from: []))
        XCTAssertNil(BestPhotoPicker.pickOriginal(from: []))
    }

    func testPickOriginalPrefersFavoriteThenEarliest() {
        let t = Date(timeIntervalSince1970: 1_700_000_000)
        let plain = [
            AnalysisRecord(id: "later", creationDate: t.addingTimeInterval(10)),
            AnalysisRecord(id: "earlier", creationDate: t),
        ]
        XCTAssertEqual(BestPhotoPicker.pickOriginal(from: plain), "earlier")

        let withFavorite = plain + [AnalysisRecord(id: "fav", creationDate: t.addingTimeInterval(99), isFavorite: true)]
        XCTAssertEqual(BestPhotoPicker.pickOriginal(from: withFavorite), "fav")
    }
}
