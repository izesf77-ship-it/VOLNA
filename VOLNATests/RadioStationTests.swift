import XCTest
@testable import VOLNA

final class RadioStationTests: XCTestCase {
    func testDecodesRadioBrowserStation() throws {
        let json = """
        {
          "stationuuid": "uuid-1",
          "name": "  Radio Test  ",
          "url": "http://example.com/stream",
          "url_resolved": "https://example.com/resolved",
          "homepage": "https://example.com",
          "favicon": "https://example.com/icon.png",
          "country": "Germany",
          "countrycode": "de",
          "state": "Berlin",
          "language": "german, english",
          "languagecodes": "de,en",
          "tags": "pop, rock,pop",
          "codec": "MP3",
          "bitrate": 128,
          "votes": "42",
          "clickcount": 7,
          "lastcheckok": 1,
          "lastchecktime": "2026-11-12 03:23:16"
        }
        """

        let station = try JSONDecoder().decode(RadioStation.self, from: Data(json.utf8))

        XCTAssertEqual(station.stationUUID, "uuid-1")
        XCTAssertEqual(station.name, "Radio Test")
        XCTAssertEqual(station.playbackURL?.absoluteString, "https://example.com/resolved")
        XCTAssertEqual(station.countryCode, "DE")
        XCTAssertEqual(station.state, "Berlin")
        XCTAssertEqual(station.languageCodes, ["de", "en"])
        XCTAssertEqual(station.tags, ["pop", "rock"])
        XCTAssertEqual(station.bitrate, 128)
        XCTAssertEqual(station.votes, 42)
        XCTAssertTrue(station.lastCheckOK)
        XCTAssertNotNil(station.lastCheckTime)
        XCTAssertTrue(station.isPlayable)
        XCTAssertEqual(station.flagEmoji, "🇩🇪")
    }

    func testToleratesMissingAndStringEncodedFields() throws {
        let json = """
        {
          "stationuuid": "uuid-2",
          "name": "Broken",
          "url": "ftp://example.com/stream",
          "lastcheckok": "0",
          "bitrate": "96",
          "countrycode": "",
          "languagecodes": null,
          "tags": null
        }
        """

        let station = try JSONDecoder().decode(RadioStation.self, from: Data(json.utf8))

        XCTAssertEqual(station.stationUUID, "uuid-2")
        XCTAssertNil(station.playbackURL)
        XCTAssertNil(station.countryCode)
        XCTAssertEqual(station.bitrate, 96)
        XCTAssertTrue(station.tags.isEmpty)
        XCTAssertFalse(station.lastCheckOK)
        XCTAssertFalse(station.isPlayable)
        XCTAssertNil(station.lastCheckTime)
    }

    func testPlayabilityRequiresNameHealthyFlagAndHTTPStream() {
        XCTAssertTrue(RadioTestSupport.station().isPlayable)

        let noName = RadioTestSupport.station(name: "   ")
        XCTAssertFalse(noName.isPlayable)

        let broken = RadioTestSupport.station(lastCheckOK: false)
        XCTAssertFalse(broken.isPlayable)

        let ftp = RadioTestSupport.station(url: "ftp://example.com/live")
        XCTAssertFalse(ftp.isPlayable)

        let localhostWithoutScheme = RadioTestSupport.station(url: "example.com/live")
        XCTAssertFalse(localhostWithoutScheme.isPlayable)
    }

    func testPlaybackURLPrefersResolvedAddress() {
        let station = RadioTestSupport.station(
            url: "http://example.com/original",
            resolvedURL: "https://example.com/resolved"
        )
        XCTAssertEqual(station.playbackURL?.absoluteString, "https://example.com/resolved")
        XCTAssertTrue(station.isHTTPS)
    }

    func testRussianQueryUsesLanguageNameNotLanguageCodes() {
        let query = RadioStationQuery.russian(limit: 30)

        XCTAssertEqual(value("language", in: query), "russian")
        XCTAssertNil(value("languagecodes", in: query))
        XCTAssertEqual(value("order", in: query), "clickcount")
        XCTAssertEqual(value("reverse", in: query), "true")
        XCTAssertEqual(value("offset", in: query), "0")
        XCTAssertEqual(value("limit", in: query), "30")
        XCTAssertEqual(query.nextPage.offset, 30)
    }

    func testQueryNormalizesLimitAndCountry() {
        let country = RadioStationQuery.country("de", limit: 1_000)
        XCTAssertEqual(value("countrycode", in: country), "DE")
        XCTAssertEqual(country.normalizedLimit, 100)

        let search = RadioStationQuery.search("  Radio  ", limit: 0)
        XCTAssertEqual(value("name", in: search), "Radio")
        XCTAssertEqual(search.normalizedLimit, 1)

        let genre = RadioStationQuery.genre("Hip Hop", limit: 40)
        XCTAssertEqual(value("tag", in: genre), "hip hop")
    }

    func testPaginatorFiltersBrokenStationsAndDuplicates() {
        let query = RadioStationQuery.search("test", limit: 2)
        let raw = [
            RadioTestSupport.station(id: "a"),
            RadioTestSupport.station(id: "b", lastCheckOK: false),
            RadioTestSupport.station(id: "A", name: "Duplicate"),
            RadioTestSupport.station(id: "c")
        ]

        let page = RadioPaginator.page(raw: raw, query: query)

        XCTAssertEqual(page.stations.map(\.id), ["a", "c"])
        XCTAssertEqual(page.receivedCount, 4)
        XCTAssertTrue(page.hasMore)
        XCTAssertEqual(page.nextOffset, 4)
        XCTAssertEqual(page.nextQuery?.offset, 4)
        XCTAssertEqual(page.nextQuery?.limit, 2)
    }

    func testPaginatorStopsWhenResponseIsShort() {
        let query = RadioStationQuery.search("test", limit: 10)
        let raw = [RadioTestSupport.station(id: "a")]

        let page = RadioPaginator.page(raw: raw, query: query)

        XCTAssertEqual(page.stations.count, 1)
        XCTAssertFalse(page.hasMore)
        XCTAssertNil(page.nextOffset)
        XCTAssertNil(page.nextQuery)
    }

    func testInternationalFilterRemovesRussianLanguageAndRussianSpeakingCountries() {
        let raw = [
            RadioTestSupport.station(id: "russian-language", language: "russian,english", countryCode: "DE"),
            RadioTestSupport.station(id: "russian-country", language: "german", countryCode: "RU"),
            RadioTestSupport.station(id: "belarus", language: "english", countryCode: "BY"),
            RadioTestSupport.station(id: "germany", language: "german", countryCode: "DE")
        ]

        let filtered = RadioStationFilter.internationalOnly(raw)

        XCTAssertEqual(filtered.map(\.id), ["germany"])
    }

    func testGenreCatalogContainsOnlyUniqueTags() {
        let ids = RadioGenreCatalog.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
        XCTAssertTrue(ids.contains("jazz"))
        XCTAssertTrue(ids.contains("electronic"))
    }

    private func value(_ name: String, in query: RadioStationQuery) -> String? {
        query.queryItems.first { $0.name == name }?.value
    }
}
