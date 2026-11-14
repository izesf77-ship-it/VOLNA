import XCTest
@testable import VOLNA

final class ICYMetadataTests: XCTestCase {
    func testParsesArtistAndTitle() throws {
        let metadata = try XCTUnwrap(
            ICYMetadataParser.parse("StreamTitle='Daft Punk - One More Time';StreamUrl='';")
        )

        XCTAssertEqual(metadata.rawTitle, "Daft Punk - One More Time")
        XCTAssertEqual(metadata.artist, "Daft Punk")
        XCTAssertEqual(metadata.title, "One More Time")
        XCTAssertEqual(metadata.displayText, "Daft Punk — One More Time")
        XCTAssertEqual(metadata.secondaryText, "Daft Punk")
    }

    func testParsesTitleWithoutArtistSeparator() throws {
        let metadata = try XCTUnwrap(
            ICYMetadataParser.parse("StreamTitle='Radio News Hour';")
        )

        XCTAssertNil(metadata.artist)
        XCTAssertEqual(metadata.title, "Radio News Hour")
        XCTAssertEqual(metadata.displayText, "Radio News Hour")
        XCTAssertEqual(metadata.secondaryText, "Сейчас в эфире")
    }

    func testReturnsNilWithoutStreamTitle() {
        XCTAssertNil(ICYMetadataParser.parse("StreamUrl='https://example.com';"))
        XCTAssertNil(ICYMetadataParser.parse(""))
        XCTAssertNil(ICYMetadataParser.parse("StreamTitle='';"))
        XCTAssertNil(ICYMetadataParser.parse("StreamTitle='   ';"))
    }

    func testUnescapesQuoteInsideTitle() throws {
        let metadata = try XCTUnwrap(
            ICYMetadataParser.parse("StreamTitle='Artist - Don\\'t Stop';")
        )

        XCTAssertEqual(metadata.artist, "Artist")
        XCTAssertEqual(metadata.title, "Don't Stop")
    }

    func testParsesUTF8Data() throws {
        let raw = "StreamTitle='Кино - Звезда по имени Солнце';"
        let data = try XCTUnwrap(raw.data(using: .utf8))
        let metadata = try XCTUnwrap(ICYMetadataParser.parse(data))

        XCTAssertEqual(metadata.artist, "Кино")
        XCTAssertEqual(metadata.title, "Звезда по имени Солнце")
    }

    func testParsesWindows1251Data() throws {
        let raw = "StreamTitle='Иванушки International - Тополиный пух';"
        let data = try XCTUnwrap(raw.data(using: .windowsCP1251))
        let metadata = try XCTUnwrap(ICYMetadataParser.parse(data))

        XCTAssertEqual(metadata.artist, "Иванушки International")
        XCTAssertEqual(metadata.title, "Тополиный пух")
    }

    func testDisplayTextUsesEmDashAndKeepsRawTitle() {
        let metadata = ICYNowPlaying(rawTitle: "A - B", artist: "A", title: "B")
        XCTAssertEqual(metadata.displayText, "A — B")
        XCTAssertEqual(metadata.rawTitle, "A - B")
    }
}
