import XCTest
@testable import VOLNA

final class RadioFavoritesTests: XCTestCase {
    private var fileURL: URL!

    override func setUpWithError() throws {
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("volna-radio-favorites-\(UUID().uuidString).json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: fileURL)
    }

    @MainActor
    func testToggleAndPersistence() async throws {
        let station = RadioTestSupport.station(id: "station-1", name: "Radio One")
        let store = RadioFavoritesStore(fileURL: fileURL)

        XCTAssertTrue(store.toggle(station))
        XCTAssertTrue(store.isFavorite(station))
        XCTAssertEqual(store.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

        let restored = RadioFavoritesStore(fileURL: fileURL)
        XCTAssertEqual(restored.stations.map(\.id), ["station-1"])
        XCTAssertEqual(restored.stations.first?.name, "Radio One")
        XCTAssertNil(restored.lastError)

        XCTAssertFalse(restored.toggle(station))
        XCTAssertTrue(restored.isEmpty)

        let emptyAfterRemoval = RadioFavoritesStore(fileURL: fileURL)
        XCTAssertTrue(emptyAfterRemoval.isEmpty)
    }

    @MainActor
    func testFavoriteKeepsStationDetailsAfterReload() async {
        let station = RadioTestSupport.station(
            id: "station-details",
            name: "Radio Details",
            country: "Germany",
            countryCode: "DE",
            language: "german, english"
        )
        let store = RadioFavoritesStore(fileURL: fileURL)
        store.add(station)

        let restored = RadioFavoritesStore(fileURL: fileURL)
        let saved = restored.stations.first

        XCTAssertEqual(saved?.name, "Radio Details")
        XCTAssertEqual(saved?.countryCode, "DE")
        XCTAssertEqual(saved?.language, "german, english")
        XCTAssertEqual(saved?.tags, ["pop"])
        XCTAssertEqual(saved?.playbackURL, station.playbackURL)
        XCTAssertTrue(saved?.lastCheckOK == true)
        XCTAssertNotNil(saved?.lastCheckTime)
    }

    @MainActor
    func testAddDoesNotCreateDuplicates() async {
        let station = RadioTestSupport.station(id: "station-1")
        let store = RadioFavoritesStore(fileURL: fileURL)

        store.add(station)
        store.add(station)

        XCTAssertEqual(store.count, 1)
        XCTAssertEqual(RadioFavoritesStore(fileURL: fileURL).count, 1)
    }

    @MainActor
    func testNewestFavoriteComesFirst() async {
        let store = RadioFavoritesStore(fileURL: fileURL)
        store.add(RadioTestSupport.station(id: "first"))
        store.add(RadioTestSupport.station(id: "second"))

        XCTAssertEqual(store.stations.map(\.id), ["second", "first"])
        XCTAssertEqual(RadioFavoritesStore(fileURL: fileURL).stations.map(\.id), ["second", "first"])
    }

    @MainActor
    func testCorruptFileKeepsStoreUsable() throws {
        try Data("not-json".utf8).write(to: fileURL)

        let store = RadioFavoritesStore(fileURL: fileURL)

        XCTAssertTrue(store.isEmpty)
        XCTAssertNotNil(store.lastError)

        let station = RadioTestSupport.station(id: "station-1")
        XCTAssertTrue(store.toggle(station))
        XCTAssertEqual(RadioFavoritesStore(fileURL: fileURL).count, 1)
    }

    @MainActor
    func testFavoritesAreCappedAtTwoHundred() async {
        let store = RadioFavoritesStore(fileURL: fileURL)

        for index in 0..<205 {
            store.add(RadioTestSupport.station(id: "station-\(index)"))
        }

        XCTAssertEqual(store.count, 200)
        XCTAssertEqual(store.stations.first?.id, "station-204")
        XCTAssertEqual(RadioFavoritesStore(fileURL: fileURL).count, 200)
    }
}
