import SwiftData
import XCTest
@testable import PhotoManager

final class BlurryFilterTests: XCTestCase {
    private func records() -> [AnalysisRecord] {
        [
            AnalysisRecord(id: "sharp", sharpness: 400),
            AnalysisRecord(id: "blurry", sharpness: 30),
            AnalysisRecord(id: "blurrier", sharpness: 5),
            AnalysisRecord(id: "shot", isScreenshot: true, sharpness: 10),
            AnalysisRecord(id: "unanalyzed"),
            AnalysisRecord(id: "ignored", sharpness: 1),
        ]
    }

    func testFiltersBelowThresholdAndSortsBlurriestFirst() {
        let result = BlurryFilter.blurry(from: records(), threshold: 100, ignored: ["ignored"], includeScreenshots: false)
        XCTAssertEqual(result.map(\.id), ["blurrier", "blurry"])
    }

    func testIncludeScreenshotsAndIgnoreList() {
        let result = BlurryFilter.blurry(from: records(), threshold: 100, ignored: [], includeScreenshots: true)
        XCTAssertEqual(result.map(\.id), ["ignored", "blurrier", "shot", "blurry"])
    }

    func testThresholdIsExclusive() {
        let result = BlurryFilter.blurry(from: [AnalysisRecord(id: "edge", sharpness: 100)], threshold: 100, ignored: [], includeScreenshots: true)
        XCTAssertTrue(result.isEmpty)
    }
}

final class PhotoGroupTests: XCTestCase {
    func testSimilarGroupKeepsBestAndComputesReclaimableBytes() throws {
        let members = [
            AnalysisRecord(id: "a", pixelWidth: 10, pixelHeight: 10, fileSize: 100, sharpness: 20),
            AnalysisRecord(id: "b", pixelWidth: 10, pixelHeight: 10, fileSize: 300, sharpness: 290),
            AnalysisRecord(id: "c", pixelWidth: 10, pixelHeight: 10, fileSize: 50, sharpness: 10),
        ]
        let group = try XCTUnwrap(PhotoGroup.make(from: members, kind: .similar))
        XCTAssertEqual(group.keepID, "b")
        XCTAssertEqual(group.removable.map(\.id), ["a", "c"])
        XCTAssertEqual(group.reclaimableBytes, 150)
        XCTAssertEqual(group.plan, MergePlan(keepID: "b", removeIDs: ["a", "c"]))
    }

    func testDuplicateGroupKeepsEarliest() throws {
        let t = Date(timeIntervalSince1970: 1_700_000_000)
        let members = [
            AnalysisRecord(id: "copy", creationDate: t.addingTimeInterval(60)),
            AnalysisRecord(id: "orig", creationDate: t),
        ]
        let group = try XCTUnwrap(PhotoGroup.make(from: members, kind: .duplicate))
        XCTAssertEqual(group.keepID, "orig")
    }

    func testSingleMemberIsNotAGroup() {
        XCTAssertNil(PhotoGroup.make(from: [AnalysisRecord(id: "solo")], kind: .similar))
    }
}

final class AlbumHealthReportTests: XCTestCase {
    func testNoSuggestionsForCleanLibrary() {
        XCTAssertTrue(AlbumHealthReport().suggestions.isEmpty)
    }

    func testSuggestionsRespectThresholdsAndOrder() {
        var report = AlbumHealthReport()
        report.largeVideoCount = 3
        report.largeVideoBytes = 3_000_000_000
        report.blurryCount = 12
        report.screenshotCount = 49 // 低于 50，不提示
        report.screenRecordingCount = 5
        report.burstCount = 19 // 低于 20，不提示
        report.emptyAlbums = [AlbumSummary(id: "x", title: "空", assetCount: 0)]

        XCTAssertEqual(report.suggestions, [
            .largeVideos(count: 3, bytes: 3_000_000_000),
            .blurry(count: 12),
            .screenRecordings(count: 5),
            .emptyAlbums(count: 1),
        ])
    }

    func testAnalyzedFractionIsClamped() {
        var report = AlbumHealthReport()
        XCTAssertEqual(report.analyzedFraction, 0)
        report.photoCount = 10
        report.analyzedPhotoCount = 25
        XCTAssertEqual(report.analyzedFraction, 1)
        report.analyzedPhotoCount = 5
        XCTAssertEqual(report.analyzedFraction, 0.5, accuracy: 0.0001)
    }
}

final class RecordStoreTests: XCTestCase {
    private func makeStore() throws -> RecordStore {
        let schema = Schema([AssetRecord.self, IgnoredAsset.self])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
        return RecordStore(modelContainer: container)
    }

    private func meta(_ id: String, mod: TimeInterval = 1) -> AssetMeta {
        AssetMeta(
            id: id,
            creationDate: Date(timeIntervalSince1970: 100),
            modificationDate: Date(timeIntervalSince1970: mod),
            pixelWidth: 40,
            pixelHeight: 30,
            burstIdentifier: nil,
            isFavorite: false
        )
    }

    func testSyncInsertsAndPrunesMissingAssets() async throws {
        let store = try makeStore()
        let first = try await store.sync([meta("a"), meta("b")])
        XCTAssertEqual(Set(first.map(\.id)), ["a", "b"])

        let second = try await store.sync([meta("b"), meta("c")])
        XCTAssertEqual(Set(second.map(\.id)), ["b", "c"])
    }

    func testAnalysisSurvivesResyncUntilAssetIsModified() async throws {
        let store = try makeStore()
        _ = try await store.sync([meta("a", mod: 1)])
        try await store.apply(basic: [BasicAnalysis(id: "a", sharpness: 42, dHash: UInt64.max)])

        var records = try await store.sync([meta("a", mod: 1)])
        XCTAssertEqual(records.first?.sharpness, 42)
        XCTAssertEqual(records.first?.dHash, UInt64.max)

        records = try await store.sync([meta("a", mod: 2)])
        XCTAssertNil(records.first?.sharpness)
        XCTAssertNil(records.first?.dHash)
    }

    func testIgnoreListRoundTrip() async throws {
        let store = try makeStore()
        try await store.ignore(["a", "b"], reason: "blurry")
        try await store.ignore(["b", "c"], reason: "blurry")
        let ignored = try await store.ignoredIDs()
        XCTAssertEqual(ignored, ["a", "b", "c"])

        try await store.unignore(["b"])
        let remaining = try await store.ignoredIDs()
        XCTAssertEqual(remaining, ["a", "c"])
    }

    func testApplyHashesAndFileSizes() async throws {
        let store = try makeStore()
        _ = try await store.sync([meta("a")])
        try await store.apply(fileSizes: [(id: "a", size: 1234)])
        try await store.apply(hashes: [(id: "a", hash: "deadbeef")])
        let record = try await store.records(ids: ["a"]).first
        XCTAssertEqual(record?.fileSize, 1234)
        XCTAssertEqual(record?.contentHash, "deadbeef")
    }
}
