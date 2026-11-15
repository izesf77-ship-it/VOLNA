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

/// Режим единственного AVPlayer. Музыка и радио никогда не играют
/// одновременно: переключение заменяет текущий item у того же плеера.
enum PlaybackMode: String, Codable, Equatable, Sendable {
    case music
    case radio
}

/// Снимок музыкального воспроизведения на момент ухода в радио.
/// Позволяет вернуться к тому же треку и позиции без второй аудиосессии.
struct MusicResumeSnapshot: Codable, Equatable, Sendable {
    let queue: [Track]
    let currentIndex: Int
    let currentTime: TimeInterval
    let duration: TimeInterval
    let isShuffled: Bool
    let repeatMode: RepeatMode
    let shuffleOrder: [Int]
    let shufflePosition: Int
    let wasPlaying: Bool
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
    private(set) var mode: PlaybackMode = .music
    private(set) var radioStation: RadioStation?
    private(set) var radioMetadata: ICYNowPlaying?
    private(set) var isRadioReconnecting = false
    private(set) var radioReconnectAttempt = 0

    /// Есть ли что показывать в MiniPlayer / полноэкранном плеере.
    var hasNowPlaying: Bool {
        if mode == .radio { return radioStation != nil }
        return currentTrack != nil
    }

    /// Можно ли вернуть пользователя к музыке после радио.
    var hasMusicToResume: Bool {
        mode == .radio && musicResume != nil
    }

    private var musicResume: MusicResumeSnapshot?

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

    // MARK: - Radio runtime

    private var radioMetadataTask: Task<Void, Never>?
    private var radioReconnectTask: Task<Void, Never>?
    private var radioStallTicks = 0
    private var radioStableTicks = 0
    private let radioMetadataClient = ICYMetadataClient()

    // MARK: - Now Playing artwork

    private var artworkCache: [String: MPMediaItemArtwork] = [:]
    private var artworkTask: Task<Void, Never>?
    private var artworkTrackID: String?

    private let stateKey = "volna.player.state.v1"
    private let audioSession = AVAudioSession.sharedInstance()
    private let defaults: UserDefaults

    // MARK: - Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        configureAudioSession()
        setupPlayer()
        setupRemoteCommands()
        setupNotifications()
        restoreState()
    }

    // MARK: - Public control

    func play(_ track: Track, queue newQueue: [Track]? = nil) {
        leaveRadioMode(clearMusicResume: true)
        player.pause()
        mode = .music

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

    /// Запускает интернет-радио в том же AVPlayer.
    ///
    /// Музыкальная очередь и позиция не уничтожаются: они сохраняются в
    /// `musicResume`, а `currentTrack` остаётся для возврата к музыке. UI
    /// обязан смотреть на `mode`, а не только на `currentTrack`.
    func playRadio(_ station: RadioStation) {
        guard station.isPlayable, station.playbackURL != nil else {
            playbackError = "У этой радиостанции нет доступного аудиопотока."
            return
        }

        if mode == .radio, radioStation?.id == station.id {
            if !isPlaying {
                resume()
            }
            return
        }

        if mode == .music, currentTrack != nil, !queue.isEmpty {
            musicResume = MusicResumeSnapshot(
                queue: queue,
                currentIndex: currentIndex,
                currentTime: currentTime,
                duration: duration,
                isShuffled: isShuffled,
                repeatMode: repeatMode,
                shuffleOrder: shuffleOrder,
                shufflePosition: shufflePosition,
                wasPlaying: isPlaying
            )
        }

        leaveRadioMode(clearMusicResume: false)
        mode = .radio
        radioStation = station
        radioMetadata = nil
        isRadioReconnecting = false
        radioReconnectAttempt = 0
        radioStallTicks = 0
        radioStableTicks = 0
        currentTime = 0
        duration = 0
        playbackError = nil
        loadRadio(autoplay: true)
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    func resume() {
        if mode == .radio {
            if radioStation == nil { return }
            if player.currentItem == nil || player.currentItem?.status == .failed {
                radioReconnectAttempt = 0
                radioStallTicks = 0
                radioStableTicks = 0
                isRadioReconnecting = false
                playbackError = nil
                loadRadio(autoplay: true)
                return
            }

            do {
                try audioSession.setActive(true)
            } catch {
                playbackError = "Не удалось активировать аудиосессию: \(error.localizedDescription)"
            }
            radioReconnectAttempt = 0
            radioStallTicks = 0
            player.play()
            isPlaying = true
            startRadioMetadataProbe()
            updateNowPlayingInfo()
            saveState()
            return
        }

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

        // После конца очереди currentTime равен duration: resume с конца
        // ничего не воспроизведёт — начинаем текущий трек заново.
        if duration > 0, currentTime >= duration - 0.5 {
            seek(to: 0)
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
        if mode == .radio {
            stopRadioMetadataProbe()
            radioReconnectTask?.cancel()
            radioReconnectTask = nil
            isRadioReconnecting = false
            isBuffering = false
        }
        updateNowPlayingInfo()
        saveState()
    }

    func next() {
        guard mode == .music else { return }
        advance(by: 1)
    }

    func previous() {
        guard mode == .music else { return }
        guard !queue.isEmpty else { return }
        if currentTime > 3 {
            seek(to: 0)
            return
        }
        advance(by: -1)
    }

    func seek(to time: TimeInterval) {
        guard mode == .music else { return }
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
        guard mode == .music else { return }
        seek(to: currentTime + offset)
    }

    func toggleShuffle() {
        guard mode == .music else { return }
        isShuffled.toggle()
        resetShuffleOrder()
        saveState()
    }

    func cycleRepeatMode() {
        guard mode == .music else { return }
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
        saveState()
    }

    func appendToQueue(_ track: Track) {
        // Очередь принадлежит музыкальному режиму. В радио она лишь хранится
        // для возврата, и добавлять в неё треки нельзя: это могло бы заменить
        // текущий радио-поток при пустом currentTrack.
        guard mode == .music else { return }
        // Дедупликация по id: один и тот же трек не должен попадать в очередь
        // дважды, даже если объект трека собран заново с тем же потоком.
        guard !queue.contains(where: { $0.id == track.id }) else {
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
        guard mode == .music else { return }
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
        guard mode == .music else { return }
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

    /// Ручная попытка переподключения после исчерпанных автопопыток.
    func retryRadioPlayback() {
        guard mode == .radio, radioStation != nil else { return }
        radioReconnectTask?.cancel()
        radioReconnectTask = nil
        radioReconnectAttempt = 0
        radioStallTicks = 0
        radioStableTicks = 0
        isRadioReconnecting = false
        playbackError = nil
        loadRadio(autoplay: true)
    }

    /// Возвращает сохранённую музыку с той же позиции, с которой началось радио.
    func returnToMusic() {
        guard mode == .radio, let snapshot = musicResume, !snapshot.queue.isEmpty else { return }

        player.pause()
        leaveRadioMode(clearMusicResume: true)
        mode = .music

        queue = snapshot.queue
        currentIndex = min(max(snapshot.currentIndex, 0), queue.count - 1)
        repeatMode = snapshot.repeatMode
        isShuffled = snapshot.isShuffled
        shuffleOrder = snapshot.shuffleOrder
        shufflePosition = min(max(snapshot.shufflePosition, 0), max(0, queue.count - 1))
        currentTrack = queue[currentIndex]
        duration = snapshot.duration
        currentTime = snapshot.currentTime
        playbackError = nil
        // Если музыка играла до перехода в радио — продолжаем с той же
        // позиции. Если была пауза, возвращаемся на паузу, а не запускаем
        // звук против воли пользователя.
        loadCurrentTrack(autoplay: snapshot.wasPlaying)
        if snapshot.currentTime > 0 {
            pendingSeek = snapshot.currentTime
            // loadCurrentTrack сбрасывает позицию нового item в 0. Пока
            // AVPlayer не применит pendingSeek, показываем и сохраняем
            // позицию, с которой пользователь ушёл в радио.
            currentTime = snapshot.currentTime
        }
        updateNowPlayingInfo()
        saveState()
    }

    func stop() {
        leaveRadioMode(clearMusicResume: true)
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
        defaults.removeObject(forKey: stateKey)
    }

    func saveState() {
        guard !isRestoring else { return }
        guard !queue.isEmpty || (mode == .radio && radioStation != nil) else {
            defaults.removeObject(forKey: stateKey)
            return
        }

        let snapshot = PersistedPlayerState(
            queue: queue,
            currentIndex: currentIndex,
            currentTime: mode == .music ? currentTime : 0,
            repeatMode: repeatMode,
            isShuffled: isShuffled,
            savedAt: Date(),
            mode: mode,
            radioStation: radioStation,
            musicResume: musicResume
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: stateKey)
    }

    // MARK: - Radio lifecycle

    private func leaveRadioMode(clearMusicResume: Bool) {
        radioMetadataTask?.cancel()
        radioMetadataTask = nil
        radioReconnectTask?.cancel()
        radioReconnectTask = nil
        mode = .music
        radioStation = nil
        radioMetadata = nil
        isRadioReconnecting = false
        radioReconnectAttempt = 0
        radioStallTicks = 0
        radioStableTicks = 0
        if clearMusicResume {
            musicResume = nil
        }
    }

    private func loadRadio(autoplay: Bool) {
        guard let station = radioStation, let url = station.playbackURL else {
            playbackError = "У этой радиостанции нет доступного аудиопотока."
            isPlaying = false
            isBuffering = false
            return
        }

        do {
            try audioSession.setActive(true)
        } catch {
            playbackError = "Не удалось активировать аудиосессию: \(error.localizedDescription)"
        }

        let item = AVPlayerItem(url: url)
        item.preferredForwardBufferDuration = 4
        player.replaceCurrentItem(with: item)

        duration = 0
        currentTime = 0
        isBuffering = true
        isRadioReconnecting = false
        radioStallTicks = 0
        radioStableTicks = 0
        pendingSeek = nil
        playbackError = nil

        if autoplay {
            player.play()
            isPlaying = true
            startRadioMetadataProbe()
        } else {
            isPlaying = false
            stopRadioMetadataProbe()
        }

        updateNowPlayingInfo()
        loadRadioArtwork(for: station)
        saveState()
    }

    private func startRadioMetadataProbe() {
        guard mode == .radio, let station = radioStation, let url = station.playbackURL else { return }
        radioMetadataTask?.cancel()
        let client = radioMetadataClient
        radioMetadataTask = Task { [weak self] in
            var failedAttempts = 0
            while !Task.isCancelled {
                guard let metadata = await client.fetch(from: url) else {
                    failedAttempts += 1
                    // Не все станции отдают ICY-метаданные. Не долбим поток
                    // бесконечно: три попытки, затем живём без метаданных.
                    guard failedAttempts < 3 else { return }
                    try? await Task.sleep(nanoseconds: 30_000_000_000)
                    continue
                }
                failedAttempts = 0
                guard let self, !Task.isCancelled else { return }
                guard self.mode == .radio, self.radioStation?.id == station.id else { return }
                if self.radioMetadata?.rawTitle != metadata.rawTitle {
                    self.radioMetadata = metadata
                    self.updateNowPlayingInfo()
                }
                try? await Task.sleep(nanoseconds: 30_000_000_000)
            }
        }
    }

    private func stopRadioMetadataProbe() {
        radioMetadataTask?.cancel()
        radioMetadataTask = nil
    }

    private func handleRadioTimeUpdate(_ time: CMTime) {
        if time.isNumeric {
            let seconds = time.seconds
            if seconds.isFinite, seconds >= 0 {
                currentTime = seconds
            }
        }

        guard let item = player.currentItem else { return }
        if item.status == .failed {
            isBuffering = false
            scheduleRadioReconnect()
            return
        }
        if item.status == .readyToPlay {
            duration = 0
        }

        switch player.timeControlStatus {
        case .playing:
            isBuffering = false
            radioStallTicks = 0
            radioStableTicks += 1
            if isRadioReconnecting {
                isRadioReconnecting = false
            }
            if radioStableTicks >= 20 {
                radioReconnectAttempt = 0
                if playbackError != nil {
                    playbackError = nil
                }
            }
            applyTimedMetadataIfAvailable()
        case .waitingToPlayAtSpecifiedRate:
            isBuffering = true
            radioStableTicks = 0
            guard isPlaying else { return }
            radioStallTicks += 1
            if radioStallTicks >= 30 {
                radioStallTicks = 0
                scheduleRadioReconnect()
            }
        case .paused:
            isBuffering = false
        @unknown default:
            isBuffering = false
        }
    }

    private func scheduleRadioReconnect() {
        guard mode == .radio, radioStation != nil, isPlaying, !isRadioReconnecting else { return }

        guard radioReconnectAttempt < 3 else {
            isPlaying = false
            isBuffering = false
            isRadioReconnecting = false
            playbackError = "Не удалось восстановить поток радиостанции. Проверьте соединение и попробуйте снова."
            updateNowPlayingInfo()
            saveState()
            return
        }

        radioReconnectAttempt += 1
        isRadioReconnecting = true
        isBuffering = true
        playbackError = "Соединение с радиостанцией прервано. Переподключение \(radioReconnectAttempt) из 3…"
        // Намеренно не вызываем pause(): он сбрасывает isPlaying, а задача
        // переподключения ниже проверяет его как признак намерения
        // пользователя. Старый item сам заменится при loadRadio.
        updateNowPlayingInfo()
        saveState()

        let attempt = radioReconnectAttempt
        let stationID = radioStation?.id
        radioReconnectTask?.cancel()
        radioReconnectTask = Task { [weak self] in
            let delay = UInt64(min(2 * attempt, 6)) * 1_000_000_000
            try? await Task.sleep(nanoseconds: delay)
            guard let self, !Task.isCancelled else { return }
            guard self.mode == .radio,
                  self.radioStation?.id == stationID,
                  self.isPlaying else {
                self.isRadioReconnecting = false
                return
            }
            self.isRadioReconnecting = false
            self.loadRadio(autoplay: true)
        }
    }

    private func applyTimedMetadataIfAvailable() {
        guard mode == .radio,
              let metadataItems = player.currentItem?.timedMetadata,
              !metadataItems.isEmpty else {
            return
        }

        var artist: String?
        var title: String?
        for metadata in metadataItems {
            guard let value = metadata.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty else { continue }
            if metadata.commonKey == .commonKeyArtist {
                artist = value
            } else if metadata.commonKey == .commonKeyTitle {
                title = value
            }
        }

        let cleanTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanArtist = artist?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let cleanTitle, !cleanTitle.isEmpty else { return }

        let raw = cleanArtist.map { "\($0) - \(cleanTitle)" } ?? cleanTitle
        guard raw != radioMetadata?.rawTitle else { return }
        radioMetadata = ICYNowPlaying(
            rawTitle: raw,
            artist: cleanArtist?.isEmpty == false ? cleanArtist : nil,
            title: cleanTitle
        )
    }

    // MARK: - Loading

    private var streamAttemptIndex: Int = 0

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
                if self.mode == .radio {
                    self.scheduleRadioReconnect()
                    return
                }
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
                if self.mode == .radio {
                    self.isBuffering = false
                    self.scheduleRadioReconnect()
                    return
                }
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
        if mode == .radio {
            handleRadioTimeUpdate(time)
            updateNowPlayingInfo()
            return
        }

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
        updateRemoteCommandAvailability()
    }

    private func updateNowPlayingInfo() {
        // Создаём и активируем NSUserActivity для привязки Now Playing к VOLNA
        let activity = NSUserActivity(activityType: "com.volna.app.nowplaying")
        activity.title = "VOLNA Now Playing"
        activity.isEligibleForHandoff = true
        activity.isEligibleForSearch = false
        activity.becomeCurrent()
        
        if mode == .radio, let station = radioStation {
            var info: [String: Any] = [
                MPMediaItemPropertyTitle: station.displayName,
                MPMediaItemPropertyArtist: radioMetadata?.displayText ?? "Прямой эфир",
                MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
                MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
                MPNowPlayingInfoPropertyIsLiveStream: true
            ]
            if !station.locationText.isEmpty {
                info[MPMediaItemPropertyAlbumTitle] = station.locationText
            }
            if let artwork = artworkCache[radioArtworkKey(for: station)] {
                info[MPMediaItemPropertyArtwork] = artwork
            }
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
            updateRemoteCommandAvailability()
            return
        }

        guard let track = currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            activity.invalidate()
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
        updateRemoteCommandAvailability()
    }

    private func updateRemoteCommandAvailability() {
        let center = MPRemoteCommandCenter.shared()
        let musicEnabled = mode == .music
        center.nextTrackCommand.isEnabled = musicEnabled
        center.previousTrackCommand.isEnabled = musicEnabled
        center.changePlaybackPositionCommand.isEnabled = musicEnabled
        center.skipForwardCommand.isEnabled = musicEnabled
        center.skipBackwardCommand.isEnabled = musicEnabled
    }

    private func radioArtworkKey(for station: RadioStation) -> String {
        "radio:\(station.id)"
    }

    private func loadArtwork(for track: Track) {
        guard let url = track.artworkURL else { return }
        loadArtwork(url: url, cacheKey: track.id, target: .music(track.id))
    }

    private func loadRadioArtwork(for station: RadioStation) {
        guard let url = station.favicon else { return }
        loadArtwork(
            url: url,
            cacheKey: radioArtworkKey(for: station),
            target: .radio(station.id)
        )
    }

    private enum ArtworkTarget {
        case music(String)
        case radio(String)
    }

    private func loadArtwork(url: URL, cacheKey: String, target: ArtworkTarget) {
        if artworkCache[cacheKey] != nil { return }
        if artworkTrackID == cacheKey, artworkTask != nil { return }

        artworkTask?.cancel()
        artworkTrackID = cacheKey

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
            self.artworkCache[cacheKey] = artwork
            if self.artworkCache.count > 24 {
                self.artworkCache.removeAll()
                self.artworkCache[cacheKey] = artwork
            }

            switch target {
            case .music(let id):
                if self.mode == .music, self.currentTrack?.id == id {
                    self.updateNowPlayingInfo()
                }
            case .radio(let id):
                if self.mode == .radio, self.radioStation?.id == id {
                    self.updateNowPlayingInfo()
                }
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
        guard let data = defaults.data(forKey: stateKey),
              let snapshot = try? JSONDecoder().decode(PersistedPlayerState.self, from: data) else {
            return
        }
        let restoredMode = snapshot.mode ?? .music
        guard !snapshot.queue.isEmpty
                || (restoredMode == .radio && snapshot.radioStation != nil) else {
            return
        }

        isRestoring = true
        queue = snapshot.queue
        currentIndex = queue.isEmpty ? 0 : min(max(snapshot.currentIndex, 0), queue.count - 1)
        repeatMode = snapshot.repeatMode
        isShuffled = snapshot.isShuffled
        currentTrack = queue.indices.contains(currentIndex) ? queue[currentIndex] : nil
        isPlaying = false
        isBuffering = false

        if restoredMode == .radio, let station = snapshot.radioStation {
            mode = .radio
            radioStation = station
            radioMetadata = nil
            isRadioReconnecting = false
            radioReconnectAttempt = 0
            currentTime = 0
            duration = 0
            resetShuffleOrder()

            if let resume = snapshot.musicResume, !resume.queue.isEmpty {
                musicResume = resume
                shuffleOrder = resume.shuffleOrder
                shufflePosition = min(max(resume.shufflePosition, 0), max(0, queue.count - 1))
            } else if !queue.isEmpty {
                musicResume = MusicResumeSnapshot(
                    queue: queue,
                    currentIndex: currentIndex,
                    currentTime: snapshot.currentTime,
                    duration: currentTrack?.duration ?? 0,
                    isShuffled: isShuffled,
                    repeatMode: repeatMode,
                    shuffleOrder: shuffleOrder,
                    shufflePosition: shufflePosition,
                    wasPlaying: false
                )
            }

            isRestoring = false
            updateNowPlayingInfo()
            loadRadioArtwork(for: station)
            return
        }

        mode = .music
        radioStation = nil
        radioMetadata = nil
        isRadioReconnecting = false
        radioReconnectAttempt = 0
        musicResume = nil
        duration = currentTrack?.duration ?? 0
        currentTime = max(0, snapshot.currentTime)
        resetShuffleOrder()

        if let stream = currentTrack?.primaryStream {
            let item = AVPlayerItem(url: stream.streamURL)
            player.replaceCurrentItem(with: item)
            // Позицию восстанавливаем через pendingSeek: свежий AVPlayerItem
            // ещё не готов, прямой seek до readyToPlay отбрасывается плеером.
            // handleTimeUpdate применит pendingSeek, когда станет известна
            // длительность элемента.
            pendingSeek = currentTime
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
    let mode: PlaybackMode?
    let radioStation: RadioStation?
    let musicResume: MusicResumeSnapshot?
}
