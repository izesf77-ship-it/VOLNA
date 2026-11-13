import Foundation
import AVFoundation
import MediaPlayer
import Observation
import UIKit

enum RepeatMode: String, Codable, CaseIterable, Sendable {
    case off
    case all
    case one

    var title: String {
        switch self {
        case .off: return "Выключено"
        case .all: return "Повторять очередь"
        case .one: return "Повторять трек"
        }
    }

    var icon: String {
        switch self {
        case .off, .all: return "repeat"
        case .one: return "repeat.1"
        }
    }
}

/// Реальный музыкальный плеер на AVPlayer.
///
/// Поддерживает очередь, перемешивание, повтор, seek, фоновое
/// воспроизведение, экран блокировки, Control Center, обработку прерываний и
/// восстановление состояния после перезапуска приложения.
@MainActor
@Observable
final class PlayerService {
    // MARK: - Observable state

    private(set) var currentTrack: Track?
    private(set) var isPlaying = false
    private(set) var isBuffering = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var queue: [Track] = []
    private(set) var currentIndex: Int = 0
    private(set) var playbackError: String?
    private(set) var isShuffled = false
    private(set) var repeatMode: RepeatMode = .off

    // MARK: - AVPlayer

    private let player = AVPlayer()
    private var timeObserver: Any?
    private var itemEndObserver: NSObjectProtocol?
    private var itemFailedObserver: NSObjectProtocol?
    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?

    private var shuffleOrder: [Int] = []
    private var shufflePosition: Int = 0
    private var isRestoring = false
    private var wasPlayingBeforeInterruption = false
    private var pendingSeek: TimeInterval?

    // MARK: - Now Playing artwork

    private var artworkCache: [String: MPMediaItemArtwork] = [:]
    private var artworkTask: Task<Void, Never>?
    private var artworkTrackID: String?

    private let stateKey = "volna.player.state.v1"
    private let audioSession = AVAudioSession.sharedInstance()

    // MARK: - Init

    init() {
        configureAudioSession()
        setupPlayer()
        setupRemoteCommands()
        setupNotifications()
        restoreState()
    }

    // MARK: - Public control

    func play(_ track: Track, queue newQueue: [Track]? = nil) {
        let resolvedQueue: [Track]
        if let newQueue, !newQueue.isEmpty {
            resolvedQueue = newQueue
        } else {
            resolvedQueue = [track]
        }

        queue = resolvedQueue
        currentIndex = resolvedQueue.firstIndex(where: { $0.id == track.id }) ?? 0
        currentTrack = resolvedQueue.indices.contains(currentIndex) ? resolvedQueue[currentIndex] : track
        playbackError = nil
        resetShuffleOrder()
        loadCurrentTrack(autoplay: true)
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    func resume() {
        if currentTrack == nil {
            guard let first = queue.first else { return }
            currentTrack = first
            currentIndex = 0
            loadCurrentTrack(autoplay: true)
            return
        }

        if player.currentItem == nil {
            loadCurrentTrack(autoplay: true)
            return
        }

        do {
            try audioSession.setActive(true)
        } catch {
            playbackError = "Не удалось активировать аудиосессию: \(error.localizedDescription)"
        }
        player.play()
        isPlaying = true
        updateNowPlayingInfo()
        saveState()
    }

    func pause() {
        player.pause()
        isPlaying = false
        updateNowPlayingInfo()
        saveState()
    }

    func next() {
        advance(by: 1)
    }

    func previous() {
        guard !queue.isEmpty else { return }
        if currentTime > 3 {
            seek(to: 0)
            return
        }
        advance(by: -1)
    }

    func seek(to time: TimeInterval) {
        guard currentTrack != nil else { return }
        let maxTime = duration > 0 ? duration : max(time, 0)
        let clamped = min(max(time, 0), maxTime)
        let target = CMTime(seconds: clamped, preferredTimescale: 600)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = clamped
        pendingSeek = nil
        updateNowPlayingInfo()
        saveState()
    }

    func seek(by offset: TimeInterval) {
        seek(to: currentTime + offset)
    }

    func toggleShuffle() {
        isShuffled.toggle()
        resetShuffleOrder()
        saveState()
    }

    func cycleRepeatMode() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
        saveState()
    }

    func appendToQueue(_ track: Track) {
        guard !queue.contains(where: { $0.id == track.id && $0.primaryStream?.streamURL == track.primaryStream?.streamURL }) else {
            return
        }
        queue.append(track)
        if currentTrack == nil {
            currentIndex = 0
            currentTrack = track
            resetShuffleOrder()
            loadCurrentTrack(autoplay: false)
        } else {
            resetShuffleOrder()
        }
        saveState()
    }

    func playNext(_ track: Track) {
        guard currentTrack != nil else {
            play(track, queue: [track])
            return
        }
        let insertIndex = min(currentIndex + 1, queue.count)
        queue.insert(track, at: insertIndex)
        resetShuffleOrder()
        saveState()
    }

    func removeFromQueue(id: String) {
        guard let index = queue.firstIndex(where: { $0.id == id }) else { return }
        let removingCurrent = index == currentIndex
        let wasPlaying = isPlaying
        queue.remove(at: index)

        if queue.isEmpty {
            stop()
            return
        }

        if index < currentIndex {
            currentIndex -= 1
        }
        currentIndex = min(max(currentIndex, 0), queue.count - 1)

        if removingCurrent {
            currentTrack = queue[currentIndex]
            resetShuffleOrder()
            loadCurrentTrack(autoplay: wasPlaying)
        } else {
            currentTrack = queue[currentIndex]
            resetShuffleOrder()
            saveState()
        }
    }

    func clearQueue() {
        stop()
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        currentTrack = nil
        queue = []
        currentIndex = 0
        currentTime = 0
        duration = 0
        isPlaying = false
        isBuffering = false
        playbackError = nil
        shuffleOrder = []
        shufflePosition = 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        UserDefaults.standard.removeObject(forKey: stateKey)
    }

    func saveState() {
        guard !isRestoring else { return }
        guard !queue.isEmpty else {
            UserDefaults.standard.removeObject(forKey: stateKey)
            return
        }

        let snapshot = PersistedPlayerState(
            queue: queue,
            currentIndex: currentIndex,
            currentTime: currentTime,
            repeatMode: repeatMode,
            isShuffled: isShuffled,
            savedAt: Date()
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: stateKey)
    }

    // MARK: - Loading

    private var streamAttemptIndex: Int = 0
    private var isAdvancingAfterFailure = false

    private func loadCurrentTrack(autoplay: Bool) {
        guard let track = currentTrack else { return }
        let streams = track.playableStreams
        guard !streams.isEmpty else {
            playbackError = "У этой композиции нет потока, совместимого с AVPlayer"
            isPlaying = false
            isBuffering = false
            return
        }
        streamAttemptIndex = 0
        loadStream(streams[0], for: track, autoplay: autoplay)
    }

    private func loadStream(_ stream: StreamSource, for track: Track, autoplay: Bool) {
        do {
            try audioSession.setActive(true)
        } catch {
            playbackError = "Не удалось активировать аудиосессию: \(error.localizedDescription)"
        }

        let item = AVPlayerItem(url: stream.streamURL)
        item.preferredForwardBufferDuration = 6
        player.replaceCurrentItem(with: item)

        duration = track.duration ?? 0
        currentTime = 0
        playbackError = nil
        isBuffering = true
        pendingSeek = nil

        if autoplay {
            player.play()
            isPlaying = true
        } else {
            isPlaying = false
        }

        updateNowPlayingInfo()
        loadArtwork(for: track)
        saveState()
    }

    private func tryFallbackStream(for track: Track) -> Bool {
        let streams = track.playableStreams
        let nextIndex = streamAttemptIndex + 1
        guard streams.indices.contains(nextIndex) else { return false }
        streamAttemptIndex = nextIndex
        loadStream(streams[nextIndex], for: track, autoplay: isPlaying || isBuffering)
        return true
    }

    private func advance(by offset: Int) {
        guard !queue.isEmpty else { return }

        if isShuffled, !shuffleOrder.isEmpty {
            let targetPosition = shufflePosition + offset
            if targetPosition >= shuffleOrder.count {
                if repeatMode == .all {
                    shufflePosition = 0
                } else {
                    finishQueue()
                    return
                }
            } else if targetPosition < 0 {
                if repeatMode == .all {
                    shufflePosition = max(0, shuffleOrder.count - 1)
                } else {
                    seek(to: 0)
                    return
                }
            } else {
                shufflePosition = targetPosition
            }
            guard shuffleOrder.indices.contains(shufflePosition) else { return }
            currentIndex = shuffleOrder[shufflePosition]
        } else {
            let targetIndex = currentIndex + offset
            if targetIndex >= queue.count {
                if repeatMode == .all {
                    currentIndex = 0
                } else {
                    finishQueue()
                    return
                }
            } else if targetIndex < 0 {
                seek(to: 0)
                return
            } else {
                currentIndex = targetIndex
            }
        }

        guard queue.indices.contains(currentIndex) else { return }
        currentTrack = queue[currentIndex]
        loadCurrentTrack(autoplay: true)
    }

    private func handleTrackEnd() {
        switch repeatMode {
        case .one:
            seek(to: 0)
            resume()
        case .all:
            advance(by: 1)
        case .off:
            let hasNext: Bool
            if isShuffled, !shuffleOrder.isEmpty {
                hasNext = shufflePosition + 1 < shuffleOrder.count
            } else {
                hasNext = currentIndex + 1 < queue.count
            }
            if hasNext {
                advance(by: 1)
            } else {
                finishQueue()
            }
        }
    }

    private func finishQueue() {
        player.pause()
        isPlaying = false
        isBuffering = false
        currentTime = duration
        updateNowPlayingInfo()
        saveState()
    }

    // MARK: - Player setup

    private func setupPlayer() {
        player.automaticallyWaitsToMinimizeStalling = true
        player.allowsExternalPlayback = true

        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                self?.handleTimeUpdate(time)
            }
        }

        itemEndObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard let item = notification.object as? AVPlayerItem,
                      item === self.player.currentItem else { return }
                self.isBuffering = false
                self.handleTrackEnd()
            }
        }

        itemFailedObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.failedToPlayToEndTimeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard let item = notification.object as? AVPlayerItem,
                      item === self.player.currentItem else { return }
                if let track = self.currentTrack, self.tryFallbackStream(for: track) {
                    return
                }
                self.isPlaying = false
                self.isBuffering = false
                let message = (notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error)?
                    .localizedDescription
                self.playbackError = message ?? "Не удалось воспроизвести аудиопоток"
            }
        }
    }

    private func handleTimeUpdate(_ time: CMTime) {
        if time.isNumeric {
            let seconds = time.seconds
            if seconds.isFinite, seconds >= 0 {
                currentTime = seconds
            }
        }

        if let item = player.currentItem {
            if item.status == .failed {
                if let track = currentTrack, tryFallbackStream(for: track) {
                    // Switched to alternate stream/provider source.
                } else {
                    isPlaying = false
                    isBuffering = false
                    playbackError = item.error?.localizedDescription ?? "Не удалось загрузить аудиопоток"
                }
            } else if item.status == .readyToPlay {
                let itemDuration = item.duration.seconds
                if itemDuration.isFinite, itemDuration > 0 {
                    duration = itemDuration
                }
            }
        }

        isBuffering = player.timeControlStatus == .waitingToPlayAtSpecifiedRate

        if let pendingSeek, duration > 0 {
            if pendingSeek <= duration {
                seek(to: pendingSeek)
            } else {
                self.pendingSeek = nil
            }
        }

        updateNowPlayingInfo()
    }

    // MARK: - Audio session

    private func configureAudioSession() {
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [])
        } catch {
            playbackError = "Не удалось настроить аудиосессию: \(error.localizedDescription)"
        }
    }

    // MARK: - Notifications

    private func setupNotifications() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                self?.handleInterruption(notification)
            }
        }

        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                self?.handleRouteChange(notification)
            }
        }
    }

    private func handleInterruption(_ notification: Notification) {
        guard let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else {
            return
        }

        switch type {
        case .began:
            wasPlayingBeforeInterruption = isPlaying
            pause()
        case .ended:
            let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
            if options.contains(.shouldResume), wasPlayingBeforeInterruption {
                resume()
            }
        @unknown default:
            break
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: rawReason) else {
            return
        }
        if reason == .oldDeviceUnavailable {
            // Наушники отключены — останавливаем воспроизведение, как принято в iOS.
            pause()
        }
    }

    // MARK: - Remote commands / Now Playing

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.togglePlayPauseCommand.isEnabled = true
        center.nextTrackCommand.isEnabled = true
        center.previousTrackCommand.isEnabled = true
        center.changePlaybackPositionCommand.isEnabled = true
        center.skipForwardCommand.isEnabled = true
        center.skipForwardCommand.preferredIntervals = [15]
        center.skipBackwardCommand.isEnabled = true
        center.skipBackwardCommand.preferredIntervals = [15]

        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.resume() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.pause() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.togglePlayPause() }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.next() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.previous() }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            let position = event.positionTime
            Task { @MainActor [weak self] in self?.seek(to: position) }
            return .success
        }
        center.skipForwardCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.seek(by: 15) }
            return .success
        }
        center.skipBackwardCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.seek(by: -15) }
            return .success
        }

        UIApplication.shared.beginReceivingRemoteControlEvents()
    }

    private func updateNowPlayingInfo() {
        guard let track = currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0
        ]
        if let album = track.album, !album.isEmpty {
            info[MPMediaItemPropertyAlbumTitle] = album
        }
        if duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        if let artwork = artworkCache[track.id] {
            info[MPMediaItemPropertyArtwork] = artwork
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func loadArtwork(for track: Track) {
        guard let url = track.artworkURL else { return }
        if artworkCache[track.id] != nil { return }
        if artworkTrackID == track.id, artworkTask != nil { return }

        artworkTask?.cancel()
        artworkTrackID = track.id
        let trackID = track.id

        artworkTask = Task { [weak self] in
            guard let self else { return }
            guard let (data, response) = try? await URLSession.shared.data(from: url),
                  let http = response as? HTTPURLResponse,
                  http.statusCode == 200,
                  let image = UIImage(data: data) else {
                return
            }
            guard !Task.isCancelled else { return }
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            self.artworkCache[trackID] = artwork
            if self.artworkCache.count > 24 {
                self.artworkCache.removeAll()
                self.artworkCache[trackID] = artwork
            }
            if self.currentTrack?.id == trackID {
                self.updateNowPlayingInfo()
            }
        }
    }

    // MARK: - Shuffle

    private func resetShuffleOrder() {
        guard !queue.isEmpty else {
            shuffleOrder = []
            shufflePosition = 0
            return
        }
        if isShuffled {
            var indices = Array(queue.indices).filter { $0 != currentIndex }
            indices.shuffle()
            shuffleOrder = [currentIndex] + indices
            shufflePosition = 0
        } else {
            shuffleOrder = Array(queue.indices)
            shufflePosition = min(currentIndex, max(0, queue.count - 1))
        }
    }

    // MARK: - Restore

    private func restoreState() {
        guard let data = UserDefaults.standard.data(forKey: stateKey),
              let snapshot = try? JSONDecoder().decode(PersistedPlayerState.self, from: data),
              !snapshot.queue.isEmpty else {
            return
        }

        isRestoring = true
        queue = snapshot.queue
        currentIndex = min(max(snapshot.currentIndex, 0), queue.count - 1)
        repeatMode = snapshot.repeatMode
        isShuffled = snapshot.isShuffled
        currentTrack = queue[currentIndex]
        duration = currentTrack?.duration ?? 0
        currentTime = max(0, snapshot.currentTime)
        isPlaying = false
        resetShuffleOrder()

        if let stream = currentTrack?.primaryStream {
            let item = AVPlayerItem(url: stream.streamURL)
            player.replaceCurrentItem(with: item)
            pendingSeek = currentTime
            if currentTime > 0 {
                player.seek(
                    to: CMTime(seconds: currentTime, preferredTimescale: 600),
                    toleranceBefore: .zero,
                    toleranceAfter: .zero
                )
            }
        }
        isRestoring = false
        updateNowPlayingInfo()
    }
}

// MARK: - Persistence model

private struct PersistedPlayerState: Codable {
    let queue: [Track]
    let currentIndex: Int
    let currentTime: TimeInterval
    let repeatMode: RepeatMode
    let isShuffled: Bool
    let savedAt: Date
}
