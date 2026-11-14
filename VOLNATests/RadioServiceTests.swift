import XCTest
@testable import VOLNA

final class RadioServiceTests: XCTestCase {
    @MainActor
    func testFeedLoadsSmallShelvesAndRussianLanguageQuery() async {
        let stations = (0..<12).map { index in
            RadioTestSupport.station(
                id: "station-\(index)",
                name: "Station \(index)",
                countryCode: index % 3 == 0 ? "DE" : (index % 3 == 1 ? "FR" : "US"),
                language: index % 4 == 0 ? "russian" : "english"
            )
        }
        let mock = MockRadioAPIClient(stations: stations)
        let service = RadioService(api: mock)

        await service.loadFeedIfNeeded()

        XCTAssertEqual(service.popular.count, stations.count)
        XCTAssertEqual(service.russian.count, stations.count)
        XCTAssertEqual(service.newStations.count, stations.count)
        XCTAssertFalse(service.international.isEmpty)
        XCTAssertNil(service.feedError)
        XCTAssertNotNil(service.lastFeedUpdate)

        let queries = await mock.queries()
        XCTAssertTrue(queries.contains { $0.language == "russian" })
        XCTAssertTrue(queries.contains { $0.order == .lastChangeTime })
    }

    @MainActor
    func testFullFeedStillLoadsAfterHomePopularShelf() async {
        let stations = (0..<8).map { index in
            RadioTestSupport.station(id: "station-\(index)", name: "Station \(index)")
        }
        let mock = MockRadioAPIClient(stations: stations)
        let service = RadioService(api: mock)

        await service.loadPopularIfNeeded()
        XCTAssertFalse(service.popular.isEmpty)
        XCTAssertTrue(service.russian.isEmpty)

        await service.loadFeedIfNeeded()

        XCTAssertFalse(service.russian.isEmpty)
        XCTAssertFalse(service.international.isEmpty)
        XCTAssertFalse(service.newStations.isEmpty)
    }

    @MainActor
    func testDirectoryLoadsAndSorts() async {
        let mock = MockRadioAPIClient(
            stations: [],
            countries: [
                RadioCountry(name: "France", code: "FR", stationCount: 10),
                RadioCountry(name: "Germany", code: "DE", stationCount: 100),
                RadioCountry(name: "Empty", code: "", stationCount: 5)
            ],
            languages: [
                RadioLanguage(name: "german", code: "de", stationCount: 100),
                RadioLanguage(name: "none", code: nil, stationCount: 0)
            ],
            genres: [
                RadioGenre(name: "rock", stationCount: 40),
                RadioGenre(name: "pop", stationCount: 80)
            ]
        )
        let service = RadioService(api: mock)

        await service.loadDirectoryIfNeeded()

        XCTAssertEqual(service.countries.map(\.code), ["DE", "FR"])
        XCTAssertEqual(service.languages.compactMap(\.code), ["de"])
        XCTAssertEqual(service.genres.map(\.name), ["pop", "rock"])
        XCTAssertNil(service.directoryError)
    }

    @MainActor
    func testSearchPaginatesWithoutLoadingWholeCatalog() async throws {
        let stations = (0..<45).map { index in
            RadioTestSupport.station(id: "station-\(index)", name: "Radio \(index)")
        }
        let mock = MockRadioAPIClient(stations: stations)
        let service = RadioService(api: mock)

        let first = try await service.search("Radio")

        XCTAssertEqual(first.stations.count, 30)
        XCTAssertTrue(first.hasMore)
        XCTAssertEqual(first.nextOffset, 30)
        XCTAssertEqual(first.nextQuery?.offset, 30)
        XCTAssertEqual(first.receivedCount, 30)

        let nextQuery = try XCTUnwrap(first.nextQuery)
        let second = try await service.stations(for: nextQuery)

        XCTAssertEqual(second.stations.count, 15)
        XCTAssertFalse(second.hasMore)
        XCTAssertNil(second.nextQuery)
    }

    @MainActor
    func testEmptySearchDoesNotMakeRequest() async throws {
        let mock = MockRadioAPIClient(stations: [])
        let service = RadioService(api: mock)

        let page = try await service.search("   ")

        XCTAssertTrue(page.stations.isEmpty)
        XCTAssertFalse(page.hasMore)
        let count = await mock.requestCount()
        XCTAssertEqual(count, 0)
    }

    @MainActor
    func testIdenticalQueriesUseCache() async throws {
        let stations = (0..<10).map { index in
            RadioTestSupport.station(id: "station-\(index)")
        }
        let mock = MockRadioAPIClient(stations: stations)
        let service = RadioService(api: mock)
        let query = RadioStationQuery.popular(limit: 10)

        _ = try await service.stations(for: query)
        _ = try await service.stations(for: query)

        let count = await mock.requestCount()
        XCTAssertEqual(count, 1)
    }

    @MainActor
    func testConcurrentIdenticalQueriesAreDeduplicated() async throws {
        let stations = (0..<10).map { index in
            RadioTestSupport.station(id: "station-\(index)")
        }
        let mock = MockRadioAPIClient(stations: stations, delayNanoseconds: 60_000_000)
        let service = RadioService(api: mock)
        let query = RadioStationQuery.popular(limit: 10)

        let first = Task { try await service.stations(for: query) }
        let second = Task { try await service.stations(for: query) }
        _ = try await (first.value, second.value)

        let count = await mock.requestCount()
        XCTAssertEqual(count, 1)
    }

    @MainActor
    func testTransportErrorsAreExposed() async {
        let mock = MockRadioAPIClient(stations: [], error: RadioAPIError.httpStatus(503))
        let service = RadioService(api: mock)

        await service.loadFeedIfNeeded()
        XCTAssertNotNil(service.feedError)
        XCTAssertTrue(service.popular.isEmpty)

        await service.loadDirectoryIfNeeded()
        XCTAssertNotNil(service.directoryError)
        XCTAssertTrue(service.countries.isEmpty)

        do {
            _ = try await service.search("Radio")
            XCTFail("Ожидалась ошибка сети")
        } catch {
            XCTAssertEqual(error as? RadioAPIError, .httpStatus(503))
        }
    }

    @MainActor
    func testForceRefreshBypassesPageCache() async throws {
        let stations = (0..<5).map { index in
            RadioTestSupport.station(id: "station-\(index)")
        }
        let mock = MockRadioAPIClient(stations: stations)
        let service = RadioService(api: mock)

        await service.loadPopularIfNeeded()
        await service.loadPopularIfNeeded(force: true)

        let count = await mock.requestCount()
        XCTAssertEqual(count, 2)
    }
}

// MARK: - Mock

private final class MockRadioAPIClient: RadioAPIClienting, @unchecked Sendable {
    private let stationsList: [RadioStation]
    private let countriesList: [RadioCountry]
    private let languagesList: [RadioLanguage]
    private let genresList: [RadioGenre]
    private let error: Error?
    private let delayNanoseconds: UInt64
    private let counter = RadioRequestCounter()
    private let recorder = RadioQueryRecorder()

    init(
        stations: [RadioStation],
        countries: [RadioCountry] = [],
        languages: [RadioLanguage] = [],
        genres: [RadioGenre] = [],
        error: Error? = nil,
        delayNanoseconds: UInt64 = 0
    ) {
        self.stationsList = stations
        self.countriesList = countries
        self.languagesList = languages
        self.genresList = genres
        self.error = error
        self.delayNanoseconds = delayNanoseconds
    }

    func stations(for query: RadioStationQuery) async throws -> [RadioStation] {
        await counter.increment()
        await recorder.record(query)
        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }
        if let error {
            throw error
        }
        let start = min(max(query.offset, 0), stationsList.count)
        let end = min(start + query.normalizedLimit, stationsList.count)
        return Array(stationsList[start..<end])
    }

    func countries() async throws -> [RadioCountry] {
        if let error { throw error }
        return countriesList
    }

    func languages(limit: Int) async throws -> [RadioLanguage] {
        if let error { throw error }
        return languagesList
    }

    func tags(limit: Int) async throws -> [RadioGenre] {
        if let error { throw error }
        return genresList
    }

    func requestCount() async -> Int {
        await counter.value
    }

    func queries() async -> [RadioStationQuery] {
        await recorder.value
    }
}

private actor RadioRequestCounter {
    private(set) var value = 0

    func increment() {
        value += 1
    }
}

private actor RadioQueryRecorder {
    private(set) var value: [RadioStationQuery] = []

    func record(_ query: RadioStationQuery) {
        value.append(query)
    }
}
