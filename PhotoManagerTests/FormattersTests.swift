import XCTest
@testable import PhotoManager

final class FormattersTests: XCTestCase {
    func testDurationUnderOneHour() {
        XCTAssertEqual(Formatters.duration(65), "1:05")
        XCTAssertEqual(Formatters.duration(0), "0:00")
    }

    func testDurationOverOneHour() {
        XCTAssertEqual(Formatters.duration(3723), "1:02:03")
    }

    func testNegativeDurationClampedToZero() {
        XCTAssertEqual(Formatters.duration(-5), "0:00")
    }
}

final class VideoScannerTests: XCTestCase {
    func testSortedBySizeDescending() {
        let items = [
            VideoItem(id: "a", duration: 1, fileSize: 10, creationDate: nil),
            VideoItem(id: "b", duration: 1, fileSize: 300, creationDate: nil),
            VideoItem(id: "c", duration: 1, fileSize: 50, creationDate: nil),
        ]
        let sorted = VideoScanner.sortedBySizeDescending(items)
        XCTAssertEqual(sorted.map(\.id), ["b", "c", "a"])
    }
}
