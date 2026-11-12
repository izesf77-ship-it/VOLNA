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
    
    // Stage 2: Extended metadata
    let language: String?              // ISO 639-1 code (e.g., "ru", "en")
    let originalTitle: String?         // Title in original script
    let transliteratedTitle: String?   // Latin script version
    let license: LicenseType
    let licenseURL: URL?
    let attribution: String?           // Required attribution text
    let isStreamAllowed: Bool
    let isDownloadAllowed: Bool
    let region: String?                // Country/region code
    let genre: String?
    
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
        availableStreams: [StreamSource] = [],
        language: String? = nil,
        originalTitle: String? = nil,
        transliteratedTitle: String? = nil,
        license: LicenseType = .unknown,
        licenseURL: URL? = nil,
        attribution: String? = nil,
        isStreamAllowed: Bool = true,
        isDownloadAllowed: Bool = false,
        region: String? = nil,
        genre: String? = nil
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
        self.language = language
        self.originalTitle = originalTitle
        self.transliteratedTitle = transliteratedTitle
        self.license = license
        self.licenseURL = licenseURL
        self.attribution = attribution
        self.isStreamAllowed = isStreamAllowed
        self.isDownloadAllowed = isDownloadAllowed
        self.region = region
        self.genre = genre
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


/// License types for music tracks
enum LicenseType: String, Codable, Sendable {
    case cc0 = "CC0"
    case ccBy = "CC-BY"
    case ccBySa = "CC-BY-SA"
    case ccByNd = "CC-BY-ND"
    case ccByNc = "CC-BY-NC"
    case ccByNcSa = "CC-BY-NC-SA"
    case ccByNcNd = "CC-BY-NC-ND"
    case publicDomain = "Public Domain"
    case other = "Other"
    case unknown = "Unknown"
    case restricted = "Restricted"
    
    var displayName: String {
        switch self {
        case .cc0: return "CC0 (Public Domain)"
        case .ccBy: return "CC BY"
        case .ccBySa: return "CC BY-SA"
        case .ccByNd: return "CC BY-ND"
        case .ccByNc: return "CC BY-NC"
        case .ccByNcSa: return "CC BY-NC-SA"
        case .ccByNcNd: return "CC BY-NC-ND"
        case .publicDomain: return "Public Domain"
        case .other: return "Other License"
        case .unknown: return "Unknown License"
        case .restricted: return "Restricted"
        }
    }
    
    var allowsCommercialUse: Bool {
        switch self {
        case .cc0, .publicDomain, .ccBy, .ccBySa, .ccByNd:
            return true
        case .ccByNc, .ccByNcSa, .ccByNcNd:
            return false
        case .other, .unknown, .restricted:
            return false
        }
    }
    
    var allowsDerivatives: Bool {
        switch self {
        case .cc0, .publicDomain, .ccBy, .ccBySa, .ccByNc, .ccByNcSa:
            return true
        case .ccByNd, .ccByNcNd:
            return false
        case .other, .unknown, .restricted:
            return false
        }
    }
    
    var requiresAttribution: Bool {
        switch self {
        case .cc0, .publicDomain:
            return false
        case .ccBy, .ccBySa, .ccByNd, .ccByNc, .ccByNcSa, .ccByNcNd:
            return true
        case .other, .unknown, .restricted:
            return true // Assume yes for safety
        }
    }
}
