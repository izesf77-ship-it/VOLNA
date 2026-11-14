import XCTest
@testable import VOLNA

final class PlayerServicePlaybackModeTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        suiteName = "volna.tests.player.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
    }

    @MainActor
    func testSwitchingToRadioPreservesMusicAndReturnsToIt() {
        let service = PlayerService(defaults: defaults)
        let track = RadioTestSupport.track()
        let station = RadioTestSupport.station(id: "radio-1", name: "Radio One")

        service.play(track, queue: [track])
        XCTAssertEqual(service.mode, .music)
        XCTAssertEqual(service.currentTrack?.id, track.id)

        service.playRadio(station)

        XCTAssertEqual(service.mode, .radio)
        XCTAssertEqual(service.radioStation?.id, station.id)
        XCTAssertTrue(service.hasNowPlaying)
        XCTAssertTrue(service.hasMusicToResume)
        XCTAssertEqual(service.currentTrack?.id, track.id)
        XCTAssertEqual(service.queue.map(\.id), [track.id])

        service.pause()
        XCTAssertFalse(service.isPlaying)
        XCTAssertEqual(service.mode, .radio)

        service.returnToMusic()

        XCTAssertEqual(service.mode, .music)
        XCTAssertNil(service.radioStation)
        XCTAssertEqual(service.currentTrack?.id, track.id)
        XCTAssertEqual(service.queue.map(\.id), [track.id])
        XCTAssertFalse(service.hasMusicToResume)
    }

    @MainActor
    func testReturnToMusicDoesNotAutoplayPausedMusic() {
        let service = PlayerService(defaults: defaults)
        let track = RadioTestSupport.track()
        let station = RadioTestSupport.station(id: "radio-1")

        service.play(track, queue: [track])
        service.pause()
        service.playRadio(station)
        XCTAssertTrue(service.isPlaying)

        service.returnToMusic()

        XCTAssertEqual(service.mode, .music)
        XCTAssertEqual(service.currentTrack?.id, track.id)
        XCTAssertFalse(service.isPlaying)
    }

    @MainActor
    func testRadioRestoresAfterRelaunchAndCanReturnToMusic() {
        let track = RadioTestSupport.track()
        let station = RadioTestSupport.station(id: "radio-1", name: "Radio One")

        let service = PlayerService(defaults: defaults)
        service.play(track, queue: [track])
        service.playRadio(station)
        service.saveState()

        let restored = PlayerService(defaults: defaults)

        XCTAssertEqual(restored.mode, .radio)
        XCTAssertEqual(restored.radioStation?.id, station.id)
        XCTAssertEqual(restored.currentTrack?.id, track.id)
        XCTAssertTrue(restored.hasNowPlaying)
        XCTAssertTrue(restored.hasMusicToResume)
        XCTAssertFalse(restored.isPlaying)

        restored.returnToMusic()

        XCTAssertEqual(restored.mode, .music)
        XCTAssertEqual(restored.currentTrack?.id, track.id)
        XCTAssertEqual(restored.queue.map(\.id), [track.id])
    }

    @MainActor
    func testMusicStateRestoresAfterRelaunch() {
        let track = RadioTestSupport.track()

        let service = PlayerService(defaults: defaults)
        service.play(track, queue: [track])
        service.pause()
        service.saveState()

        let restored = PlayerService(defaults: defaults)

        XCTAssertEqual(restored.mode, .music)
        XCTAssertEqual(restored.currentTrack?.id, track.id)
        XCTAssertEqual(restored.queue.map(\.id), [track.id])
        XCTAssertFalse(restored.isPlaying)
        XCTAssertNil(restored.radioStation)
    }

    @MainActor
    func testRadioPauseAndResumeKeepStation() {
        let service = PlayerService(defaults: defaults)
        let station = RadioTestSupport.station(id: "radio-1")

        service.playRadio(station)
        XCTAssertEqual(service.mode, .radio)
        XCTAssertTrue(service.isPlaying)

        service.pause()
        XCTAssertFalse(service.isPlaying)
        XCTAssertEqual(service.radioStation?.id, station.id)

        service.resume()
        XCTAssertTrue(service.isPlaying)
        XCTAssertEqual(service.mode, .radio)
    }

    @MainActor
    func testMusicQueueCannotBeMutatedByRadio() {
        let service = PlayerService(defaults: defaults)
        let track = RadioTestSupport.track()
        let other = RadioTestSupport.track(id: "track-2", title: "Другой")
        let station = RadioTestSupport.station(id: "radio-1")

        service.play(track, queue: [track])
        service.playRadio(station)

        service.appendToQueue(other)
        service.playNext(other)
        service.removeFromQueue(id: track.id)

        XCTAssertEqual(service.mode, .radio)
        XCTAssertEqual(service.radioStation?.id, station.id)
        XCTAssertEqual(service.queue.map(\.id), [track.id])
        XCTAssertEqual(service.currentTrack?.id, track.id)
    }

    @MainActor
    func testStopClearsRadioAndPersistedState() {
        let service = PlayerService(defaults: defaults)
        service.playRadio(RadioTestSupport.station(id: "radio-1"))

        service.stop()

        XCTAssertNil(service.currentTrack)
        XCTAssertNil(service.radioStation)
        XCTAssertFalse(service.hasNowPlaying)
        XCTAssertNil(defaults.data(forKey: "volna.player.state.v1"))
    }
}
