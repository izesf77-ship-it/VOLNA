import XCTest
@testable import VOLNA

final class SearchMergerTests: XCTestCase {
    private func track(
        id: String,
        providerID: String,
        title: String,
        artist: String,
        duration: TimeInterval?,
        stream: String,
        license: LicenseType = .ccBy
    ) -> Track {
        let source = StreamSource(
            providerID: providerID,
            streamURL: URL(string: stream)!,
            format: .mp3,
            license: license
        )
        return Track(
            id: id,
            title: title,
            artist: artist,
            duration: duration,
            providerID: providerID,
            sourceID: id,
            availableStreams: [source],
            license: license,
            isStreamAllowed: true
        )
    }

    func testDeduplicationKeepsMultipleStreams() {
        let first = track(
            id: "jam_1",
            providerID: "jamendo",
            title: "Звезда",
            artist: "Кино",
            duration: 200,
            stream: "https://example.com/a.mp3"
        )
        let second = track(
            id: "ia_1",
            providerID: "internet_archive",
            title: "Звезда",
            artist: "Kino",
            duration: 205,
            stream: "https://example.com/b.mp3"
        )

        let merged = SearchMerger.merge(tracks: [first, second], query: "Кино")
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged[0].availableStreams.count, 2)
        XCTAssertEqual(
            Set(merged[0].availableStreams.map(\.providerID)),
            Set(["jamendo", "internet_archive"])
        )
    }

    func testDifferentDurationsAreNotMerged() {
        let short = track(
            id: "a",
            providerID: "jamendo",
            title: "Same",
            artist: "Artist",
            duration: 180,
            stream: "https://example.com/short.mp3"
        )
        let long = track(
            id: "b",
            providerID: "jamendo",
            title: "Same",
            artist: "Artist",
            duration: 260,
            stream: "https://example.com/long.mp3"
        )

        XCTAssertEqual(SearchMerger.merge(tracks: [short, long], query: "Same").count, 2)
    }

    func testDifferentTitlesAreNotMerged() {
        let first = track(
            id: "a",
            providerID: "jamendo",
            title: "First",
            artist: "Artist",
            duration: 180,
            stream: "https://example.com/a.mp3"
        )
        let second = track(
            id: "b",
            providerID: "jamendo",
            title: "Second",
            artist: "Artist",
            duration: 180,
            stream: "https://example.com/b.mp3"
        )

        XCTAssertEqual(SearchMerger.merge(tracks: [first, second], query: "Artist").count, 2)
    }

    func testRussianTrackReceivesRankingBoost() {
        let russian = track(
            id: "ru",
            providerID: "jamendo",
            title: "Песня",
            artist: "Кино",
            duration: 200,
            stream: "https://example.com/ru.mp3"
        )
        let english = track(
            id: "en",
            providerID: "jamendo",
            title: "Song",
            artist: "Band",
            duration: 200,
            stream: "https://example.com/en.mp3"
        )

        let merged = SearchMerger.merge(tracks: [english, russian], query: "песня")
        XCTAssertEqual(merged.first?.id, "ru")
        XCTAssertTrue(merged.first?.isRussian == true)
    }

    func testEmptyInput() {
        XCTAssertTrue(SearchMerger.merge(tracks: [], query: "anything").isEmpty)
    }
}
