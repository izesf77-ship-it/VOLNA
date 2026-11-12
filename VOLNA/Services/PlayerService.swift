import Foundation
import AVFoundation
import MediaPlayer
import Observation

/// Сервис управления воспроизведением музыки
@Observable
@MainActor
final class PlayerService {
    // Playback state
    private(set) var currentTrack: Track?
    private(set) var isPlaying = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var queue: [Track] = []
    private(set) var currentIndex: Int = 0
    
    // Player configuration
    private(set) var repeatMode: RepeatMode = .off
    private(set) var isShuffled = false
    
    // Internal player
    private var player: AVPlayer?
    private var timeObserver: Any?
    
    init() {
        setupAudioSession()
        setupRemoteCommandCenter()
        setupNowPlayingInfo()
    }
    
    deinit {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        player?.pause()
    }
    
    // MARK: - Public API
    
    func play(track: Track) {
        guard let streamSource = track.availableStreams.first else {
            print("❌ No stream available for track: \(track.title)")
            return
        }
        
        currentTrack = track
        
        let playerItem = AVPlayerItem(url: streamSource.streamURL)
        
        if player == nil {
            player = AVPlayer(playerItem: playerItem)
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }
        
        player?.play()
        isPlaying = true
        
        updateNowPlayingInfo()
        startTimeObserver()
        
        print("▶️ Playing: \(track.title) by \(track.artist)")
    }
    
    func playQueue(_ tracks: [Track], startIndex: Int = 0) {
        guard !tracks.isEmpty, startIndex < tracks.count else {
            return
        }
        
        queue = tracks
        currentIndex = startIndex
        play(track: tracks[startIndex])
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingInfo()
        print("⏸ Paused")
    }
    
    func resume() {
        player?.play()
        isPlaying = true
        updateNowPlayingInfo()
        print("▶️ Resumed")
    }
    
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }
    
    func next() {
        guard !queue.isEmpty else { return }
        
        switch repeatMode {
        case .off, .all:
            currentIndex = (currentIndex + 1) % queue.count
        case .one:
            // Stay on current track
            break
        }
        
        play(track: queue[currentIndex])
    }
    
    func previous() {
        guard !queue.isEmpty else { return }
        
        if currentTime > 3.0 {
            // If more than 3 seconds played, restart current track
            seek(to: 0)
        } else {
            // Go to previous track
            currentIndex = (currentIndex - 1 + queue.count) % queue.count
            play(track: queue[currentIndex])
        }
    }
    
    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime)
        updateNowPlayingInfo()
    }
    
    func toggleRepeat() {
        repeatMode = repeatMode.next
        print("🔁 Repeat mode: \(repeatMode)")
    }
    
    func toggleShuffle() {
        isShuffled.toggle()
        if isShuffled {
            shuffleQueue()
        } else {
            // TODO: Restore original order
        }
        print("🔀 Shuffle: \(isShuffled)")
    }
    
    // MARK: - Private Methods
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("❌ Failed to setup audio session: \(error)")
        }
    }
    
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.resume()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.next()
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.previous()
            return .success
        }
        
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self?.seek(to: event.positionTime)
            return .success
        }
    }
    
    private func setupNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [:]
    }
    
    private func updateNowPlayingInfo() {
        guard let track = currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = track.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = track.artist
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = track.album
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        // TODO: Load artwork asynchronously
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    private func startTimeObserver() {
        // Remove existing observer
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        
        // Add periodic time observer
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            guard let self = self else { return }
            
            self.currentTime = time.seconds
            
            if let duration = self.player?.currentItem?.duration.seconds,
               !duration.isNaN {
                self.duration = duration
            }
            
            // Check if track ended
            if self.currentTime >= self.duration && self.duration > 0 {
                self.handleTrackEnded()
            }
        }
    }
    
    private func handleTrackEnded() {
        switch repeatMode {
        case .off:
            if currentIndex < queue.count - 1 {
                next()
            } else {
                // End of queue
                pause()
            }
        case .one:
            seek(to: 0)
            resume()
        case .all:
            next()
        }
    }
    
    private func shuffleQueue() {
        // Shuffle queue while keeping current track at current position
        guard let currentTrack = currentTrack else { return }
        
        var newQueue = queue
        newQueue.remove(at: currentIndex)
        newQueue.shuffle()
        newQueue.insert(currentTrack, at: currentIndex)
        
        queue = newQueue
    }
}

// MARK: - Supporting Types

enum RepeatMode {
    case off
    case one
    case all
    
    var next: RepeatMode {
        switch self {
        case .off: return .all
        case .all: return .one
        case .one: return .off
        }
    }
}
