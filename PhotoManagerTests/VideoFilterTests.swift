import XCTest
@testable import PhotoManager

final class VideoFilterTests: XCTestCase {
    private let day: TimeInterval = 86_400

    private func makeItems() -> [VideoItem] {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        return [
            VideoItem(id: "small", duration: 10, fileSize: 20_000_000, creationDate: base),
            VideoItem(id: "mid", duration: 90, fileSize: 200_000_000, creationDate: base.addingTimeInterval(-10 * day)),
            VideoItem(id: "big", duration: 400, fileSize: 2_000_000_000, creationDate: base.addingTimeInterval(-100 * day)),
            VideoItem(id: "nodate", duration: 700, fileSize: 600_000_000, creationDate: nil),
        ]
    }

    func testDefaultFilterHidesSmallVideosAndSortsBySize() {
        let result = VideoFilter().apply(to: makeItems())
        XCTAssertEqual(result.map(\.id), ["big", "nodate", "mid"])
    }

    func testMinSizeAndDurationCombine() {
        var filter = VideoFilter()
        filter.minSize = .mb500
        filter.minDuration = .min10
        XCTAssertEqual(filter.apply(to: makeItems()).map(\.id), ["nodate"])
    }

    func testShotBeforeExcludesNewerAndUndated() {
        var filter = VideoFilter()
        filter.minSize = .any
        filter.shotBefore = Date(timeIntervalSince1970: 1_700_000_000).addingTimeInterval(-50 * day)
        XCTAssertEqual(filter.apply(to: makeItems()).map(\.id), ["big"])
    }

    func testSortByDateAscendingPutsUndatedLast() {
        var filter = VideoFilter()
        filter.minSize = .any
        filter.sortKey = .dateAscending
        XCTAssertEqual(filter.apply(to: makeItems()).map(\.id), ["big", "mid", "small", "nodate"])
    }

    func testIsDefault() {
        XCTAssertTrue(VideoFilter().isDefault)
        var filter = VideoFilter()
        filter.minDuration = .min1
        XCTAssertFalse(filter.isDefault)
    }
}
