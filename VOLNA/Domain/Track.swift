import Foundation

/// Музыкальная композиция
struct Track: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: String
    let artist: String
    let album: String?
    let artworkURL: URL?
    let duration: TimeInterval?
    let providerID: String
    let sourceID: String
    let isrc: String?
    let explicit: Bool
    var availableStreams: [StreamSource]
    
    init(
        id: String,
        title: String,
        artist: String,
        album: String? = nil,
        artworkURL: URL? = nil,
        duration: TimeInterval? = nil,
        providerID: String,
        sourceID: String,
        isrc: String? = nil,
        explicit: Bool = false,
        availableStreams: [StreamSource] = []
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.artworkURL = artworkURL
        self.duration = duration
        self.providerID = providerID
        self.sourceID = sourceID
        self.isrc = isrc
        self.explicit = explicit
        self.availableStreams = availableStreams
    }
    
    /// Display-friendly duration string
    var durationFormatted: String? {
        guard let duration = duration else { return nil }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Track, rhs: Track) -> Bool {
        lhs.id == rhs.id
    }
}

/// Источник аудио потока
struct StreamSource: Codable, Hashable, Sendable {
    let providerID: String
    let streamURL: URL
    let format: AudioFormat
    let bitrate: Int?
    let availability: Availability
    
    enum Availability: String, Codable {
        case available
        case unavailable
        case requiresAuth
        case geoRestricted
    }
}

/// Поддерживаемые форматы аудио
enum AudioFormat: String, Codable, Sendable {
    case mp3 = "MP3"
    case aac = "AAC"
    case m4a = "M4A"
    case flac = "FLAC"
    case ogg = "OGG"
    case wav = "WAV"
    case hls = "HLS"
    case unknown = "UNKNOWN"
    
    var fileExtension: String {
        rawValue.lowercased()
    }
}
