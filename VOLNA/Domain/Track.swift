import Foundation

/// Музыкальная композиция, полученная из открытого источника.
///
/// Модель намеренно хранит лицензию и разрешения на уровне каждого источника
/// аудиопотока. После дедупликации один `Track` может содержать несколько
/// `StreamSource` от разных провайдеров, и у каждого источника может быть
/// собственная лицензия.
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

    // Расширенные метаданные
    let language: String?
    let originalTitle: String?
    let transliteratedTitle: String?
    let license: LicenseType
    let licenseURL: URL?
    let attribution: String?
    let isStreamAllowed: Bool
    let isDownloadAllowed: Bool
    let downloadURL: URL?
    let sourcePageURL: URL?
    let region: String?
    let genre: String?
    let releaseDate: Date?
    let trackNumber: Int?
    let albumID: String?

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
        isStreamAllowed: Bool = false,
        isDownloadAllowed: Bool = false,
        downloadURL: URL? = nil,
        sourcePageURL: URL? = nil,
        region: String? = nil,
        genre: String? = nil,
        releaseDate: Date? = nil,
        trackNumber: Int? = nil,
        albumID: String? = nil
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
        self.downloadURL = downloadURL
        self.sourcePageURL = sourcePageURL
        self.region = region
        self.genre = genre
        self.releaseDate = releaseDate
        self.trackNumber = trackNumber
        self.albumID = albumID
    }

    var providerDisplayName: String {
        MusicSourceCatalog.info(for: providerID)?.name ?? providerID
    }

    /// Потоки, которые действительно можно передать в AVPlayer.
    var playableStreams: [StreamSource] {
        availableStreams.filter { source in
            source.availability == .available && source.format.isPlayableByAVPlayer
        }
    }

    var primaryStream: StreamSource? {
        playableStreams.first
    }

    var isRussian: Bool {
        if language?.lowercased() == "ru" { return true }
        if LanguageDetector.isCyrillic(title) { return true }
        if LanguageDetector.isCyrillic(artist) { return true }
        return false
    }

    var durationFormatted: String? {
        guard let duration, duration.isFinite, duration > 0 else { return nil }
        let total = Int(duration.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    var searchableText: String {
        [title, artist, album, genre, transliteratedTitle]
            .compactMap { $0 }
            .joined(separator: " ")
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Track, rhs: Track) -> Bool {
        lhs.id == rhs.id
    }
}

/// Источник аудиопотока.
struct StreamSource: Codable, Hashable, Sendable, Identifiable {
    let providerID: String
    let streamURL: URL
    let format: AudioFormat
    let bitrate: Int?
    let availability: Availability
    let license: LicenseType?
    let licenseURL: URL?
    let attribution: String?

    var id: String {
        "\(providerID)|\(streamURL.absoluteString)"
    }

    enum Availability: String, Codable, Sendable {
        case available
        case unavailable
        case requiresAuth
        case geoRestricted
    }

    init(
        providerID: String,
        streamURL: URL,
        format: AudioFormat,
        bitrate: Int? = nil,
        availability: Availability = .available,
        license: LicenseType? = nil,
        licenseURL: URL? = nil,
        attribution: String? = nil
    ) {
        self.providerID = providerID
        self.streamURL = streamURL
        self.format = format
        self.bitrate = bitrate
        self.availability = availability
        self.license = license
        self.licenseURL = licenseURL
        self.attribution = attribution
    }

    var providerDisplayName: String {
        MusicSourceCatalog.info(for: providerID)?.name ?? providerID
    }
}

/// Форматы, которые умеет воспроизводить AVPlayer на iOS.
enum AudioFormat: String, Codable, Sendable, CaseIterable, Hashable {
    case mp3 = "MP3"
    case aac = "AAC"
    case m4a = "M4A"
    case flac = "FLAC"
    case wav = "WAV"
    case hls = "HLS"
    case ogg = "OGG"
    case opus = "OPUS"
    case unknown = "UNKNOWN"

    var fileExtension: String {
        switch self {
        case .mp3: return "mp3"
        case .aac: return "aac"
        case .m4a: return "m4a"
        case .flac: return "flac"
        case .wav: return "wav"
        case .hls: return "m3u8"
        case .ogg: return "ogg"
        case .opus: return "opus"
        case .unknown: return "bin"
        }
    }

    /// OGG/Opus не поддерживаются AVPlayer без стороннего декодера.
    var isPlayableByAVPlayer: Bool {
        switch self {
        case .mp3, .aac, .m4a, .flac, .wav, .hls:
            return true
        case .ogg, .opus, .unknown:
            return false
        }
    }

    var displayName: String {
        switch self {
        case .mp3: return "MP3"
        case .aac: return "AAC"
        case .m4a: return "M4A"
        case .flac: return "FLAC"
        case .wav: return "WAV"
        case .hls: return "HLS"
        case .ogg: return "OGG (не поддерживается)"
        case .opus: return "Opus (не поддерживается)"
        case .unknown: return "Неизвестный формат"
        }
    }

    static func from(mimeType: String?, pathExtension: String? = nil) -> AudioFormat {
        let mime = mimeType?.lowercased() ?? ""
        if mime.contains("mpegurl") || mime.contains("vnd.apple.mpegurl") {
            return .hls
        }
        if mime.contains("mpeg") || mime.contains("mp3") {
            return .mp3
        }
        if mime.contains("x-m4a") || mime.contains("audio/mp4") || mime.contains("audio/m4a") {
            return .m4a
        }
        if mime.contains("aac") {
            return .aac
        }
        if mime.contains("flac") {
            return .flac
        }
        if mime.contains("wav") || mime.contains("wave") {
            return .wav
        }
        if mime.contains("opus") {
            return .opus
        }
        if mime.contains("ogg") {
            return .ogg
        }
        switch pathExtension?.lowercased() {
        case "mp3": return .mp3
        case "m4a": return .m4a
        case "aac": return .aac
        case "flac": return .flac
        case "wav": return .wav
        case "m3u8": return .hls
        case "ogg": return .ogg
        case "opus": return .opus
        default: return .unknown
        }
    }
}

extension String {
    /// Стабильный хеш для идентификаторов, которые сохраняются между запусками.
    var stableFNVHash: String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }
}
