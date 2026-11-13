import XCTest
@testable import VOLNA

final class CatalogQualityTests: XCTestCase {
    private func track(
        id: String = "1",
        title: String,
        artist: String = "Тестовый исполнитель",
        album: String? = "Тестовый альбом",
        duration: TimeInterval? = 180,
        artwork: Bool = true,
        license: LicenseType = .ccBy,
        stream: Bool = true,
        releaseDate: Date? = Date(timeIntervalSince1970: 1_767_225_600)
    ) -> Track {
        let source = StreamSource(
            providerID: "jamendo",
            streamURL: URL(string: "https://example.com/track.mp3")!,
            format: .mp3,
            license: license
        )
        return Track(
            id: id,
            title: title,
            artist: artist,
            album: album,
            artworkURL: artwork ? URL(string: "https://example.com/cover.jpg") : nil,
            duration: duration,
            providerID: "jamendo",
            sourceID: id,
            availableStreams: stream ? [source] : [],
            license: license,
            isStreamAllowed: stream,
            releaseDate: releaseDate
        )
    }

    func testDedupKeyRemovesEditionAndFeaturedArtists() {
        let original = track(title: "Песня")
        let remaster = track(title: "Песня (Remastered 2024)")
        let featured = track(title: "Песня feat. Другой артист")

        XCTAssertEqual(
            CatalogQuality.dedupKey(for: original),
            CatalogQuality.dedupKey(for: remaster)
        )
        XCTAssertEqual(
            CatalogQuality.dedupKey(for: original),
            CatalogQuality.dedupKey(for: featured)
        )

        let bareRemaster = track(title: "Песня Remastered 2024")
        XCTAssertEqual(
            CatalogQuality.dedupKey(for: original),
            CatalogQuality.dedupKey(for: bareRemaster)
        )

        let live = track(title: "Песня (Live)")
        XCTAssertNotEqual(
            CatalogQuality.dedupKey(for: original),
            CatalogQuality.dedupKey(for: live)
        )
    }

    func testNoiseFilterRejectsDemoKaraokeAndServiceFiles() {
        XCTAssertTrue(CatalogQuality.isNoise(track(title: "Demo")))
        XCTAssertTrue(CatalogQuality.isNoise(track(title: "Караоке")))
        XCTAssertTrue(CatalogQuality.isNoise(track(title: "Track 07")))
        XCTAssertTrue(CatalogQuality.isNoise(track(title: "2024")))
        XCTAssertTrue(CatalogQuality.isNoise(track(title: "song.mp3")))
        XCTAssertTrue(CatalogQuality.isNoise(track(title: "Подкаст о музыке")))
    }

    func testNoiseFilterDoesNotRejectOrdinarySongTitles() {
        XCTAssertFalse(CatalogQuality.isNoise(track(title: "Cover Me")))
        XCTAssertFalse(CatalogQuality.isNoise(track(title: "Sound of Silence")))
        XCTAssertFalse(CatalogQuality.isNoise(track(title: "Voice of the Night")))
    }

    func testCoverDetectionIsNarrow() {
        XCTAssertTrue(CatalogQuality.isCoverLike(title: "Song (Cover)", album: "Album"))
        XCTAssertTrue(CatalogQuality.isCoverLike(title: "Кавер-версия", album: "Album"))
        XCTAssertTrue(CatalogQuality.isCoverLike(title: "Song", album: "Cover Album"))
        XCTAssertFalse(CatalogQuality.isCoverLike(title: "Cover Me", album: "Album"))
    }

    func testDisplayableKeepsUnknownLicense() {
        let unknown = track(title: "Честная запись", license: .unknown)
        XCTAssertTrue(CatalogQuality.isDisplayable(unknown))
    }

    func testCoversStaySearchableButNotFeatured() {
        let cover = track(title: "Песня (Cover)")
        XCTAssertTrue(CatalogQuality.isDisplayable(cover))
        XCTAssertFalse(CatalogQuality.isFeatured(cover))
    }

    func testFeaturedRequiresLicenseArtworkAlbumStreamAndDuration() {
        XCTAssertTrue(CatalogQuality.isFeatured(track(title: "Хороший релиз")))

        XCTAssertFalse(CatalogQuality.isFeatured(track(title: "Без лицензии", license: .unknown)))
        XCTAssertFalse(CatalogQuality.isFeatured(track(title: "Без обложки", artwork: false)))
        XCTAssertFalse(CatalogQuality.isFeatured(track(title: "Без альбома", album: nil)))
        XCTAssertFalse(CatalogQuality.isFeatured(track(title: "Без потока", stream: false)))
        XCTAssertFalse(CatalogQuality.isFeatured(track(title: "Короткий фрагмент", duration: 30)))
        XCTAssertFalse(CatalogQuality.isFeatured(track(title: "Слишком длинный файл", duration: 2_000)))
    }

    func testUnknownArtistAndEmptyTitleAreRejected() {
        let unknownArtist = track(title: "Трек", artist: "Неизвестный исполнитель")
        XCTAssertTrue(CatalogQuality.isUnknownArtist(unknownArtist.artist))
        XCTAssertFalse(CatalogQuality.isDisplayable(unknownArtist))

        let empty = track(title: "   ")
        XCTAssertFalse(CatalogQuality.isDisplayable(empty))
    }

    func testRecentReleaseScoresHigherThanOldRelease() {
        let calendar = Calendar(identifier: .gregorian)
        let recent = track(
            title: "Новый релиз",
            releaseDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 1))
        )
        let old = track(
            title: "Старый релиз",
            releaseDate: calendar.date(from: DateComponents(year: 2014, month: 3, day: 1))
        )

        XCTAssertGreaterThan(CatalogQuality.score(recent), CatalogQuality.score(old))
        XCTAssertTrue(CatalogQuality.isNew(recent, withinYears: 2))
        XCTAssertFalse(CatalogQuality.isNew(old, withinYears: 2))
    }
}
