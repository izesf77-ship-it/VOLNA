import XCTest
@testable import VOLNA

final class AudioFormatTests: XCTestCase {
    func testMimeTypes() {
        XCTAssertEqual(AudioFormat.from(mimeType: "audio/mpeg"), .mp3)
        XCTAssertEqual(AudioFormat.from(mimeType: "audio/mp4"), .m4a)
        XCTAssertEqual(AudioFormat.from(mimeType: "audio/aac"), .aac)
        XCTAssertEqual(AudioFormat.from(mimeType: "audio/flac"), .flac)
        XCTAssertEqual(AudioFormat.from(mimeType: "audio/wav"), .wav)
        XCTAssertEqual(AudioFormat.from(mimeType: "audio/ogg"), .ogg)
        XCTAssertEqual(AudioFormat.from(mimeType: "audio/opus"), .opus)
        XCTAssertEqual(
            AudioFormat.from(mimeType: "application/vnd.apple.mpegurl"),
            .hls
        )
    }

    func testPathExtensions() {
        XCTAssertEqual(AudioFormat.from(mimeType: nil, pathExtension: "mp3"), .mp3)
        XCTAssertEqual(AudioFormat.from(mimeType: nil, pathExtension: "M4A"), .m4a)
        XCTAssertEqual(AudioFormat.from(mimeType: nil, pathExtension: "m3u8"), .hls)
        XCTAssertEqual(AudioFormat.from(mimeType: "text/html", pathExtension: "html"), .unknown)
    }

    func testAVPlayerSupport() {
        XCTAssertTrue(AudioFormat.mp3.isPlayableByAVPlayer)
        XCTAssertTrue(AudioFormat.m4a.isPlayableByAVPlayer)
        XCTAssertTrue(AudioFormat.flac.isPlayableByAVPlayer)
        XCTAssertTrue(AudioFormat.hls.isPlayableByAVPlayer)
        XCTAssertFalse(AudioFormat.ogg.isPlayableByAVPlayer)
        XCTAssertFalse(AudioFormat.opus.isPlayableByAVPlayer)
        XCTAssertFalse(AudioFormat.unknown.isPlayableByAVPlayer)
    }

    func testDirectLinkUnknownLicenseStaysUnknown() {
        let link = DirectLink(
            title: "Track",
            artist: "Artist",
            url: URL(string: "https://example.com/track.mp3")!,
            format: .mp3,
            license: .unknown
        )
        let track = link.track
        XCTAssertEqual(track.license, .unknown)
        XCTAssertFalse(track.license.isKnownOpenLicense)
        XCTAssertTrue(track.isStreamAllowed)
        XCTAssertEqual(track.playableStreams.count, 1)
        XCTAssertEqual(track.providerID, "direct")
    }
}

final class LRCParserTests: XCTestCase {
    func testParsesHundredths() {
        let lines = LRCParser.parse("[00:12.50]Привет\n[01:05.00]Мир")
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].timestamp, 12.5, accuracy: 0.001)
        XCTAssertEqual(lines[0].text, "Привет")
        XCTAssertEqual(lines[1].timestamp, 65.0, accuracy: 0.001)
    }

    func testParsesWholeSecondsAndMilliseconds() {
        let lines = LRCParser.parse("[00:05]One\n[00:06.250]Two")
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].timestamp, 5.0, accuracy: 0.001)
        XCTAssertEqual(lines[1].timestamp, 6.25, accuracy: 0.001)
    }

    func testMultipleTimestampsInOneLine() {
        let lines = LRCParser.parse("[00:10.00][00:20.00]Chorus")
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].timestamp, 10.0, accuracy: 0.001)
        XCTAssertEqual(lines[1].timestamp, 20.0, accuracy: 0.001)
        XCTAssertEqual(Set(lines.map(\.text)), Set(["Chorus"]))
    }

    func testIgnoresMetadataLines() {
        XCTAssertTrue(LRCParser.parse("[ar:Artist]\n[ti:Title]").isEmpty)
    }

    func testSortsByTimestamp() {
        let lines = LRCParser.parse("[00:20.00]Second\n[00:10.00]First")
        XCTAssertEqual(lines.map(\.text), ["First", "Second"])
    }
}
