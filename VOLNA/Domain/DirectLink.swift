import Foundation

/// Пользовательская прямая аудиоссылка.
struct DirectLink: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var title: String
    var artist: String
    var url: URL
    var format: AudioFormat
    var contentType: String?
    var license: LicenseType
    var licenseURL: URL?
    var addedAt: Date

    init(
        id: String = UUID().uuidString,
        title: String,
        artist: String,
        url: URL,
        format: AudioFormat = .mp3,
        contentType: String? = nil,
        license: LicenseType = .unknown,
        licenseURL: URL? = nil,
        addedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.url = url
        self.format = format
        self.contentType = contentType
        self.license = license
        self.licenseURL = licenseURL
        self.addedAt = addedAt
    }

    var track: Track {
        let displayArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Неизвестный исполнитель" : artist
        let stream = StreamSource(
            providerID: "direct",
            streamURL: url,
            format: format,
            bitrate: nil,
            availability: format.isPlayableByAVPlayer ? .available : .unavailable,
            license: license,
            licenseURL: licenseURL,
            attribution: "«\(title)» — \(displayArtist). Источник: прямая ссылка пользователя."
        )
        return Track(
            id: "direct_\(id)",
            title: title,
            artist: displayArtist,
            album: nil,
            artworkURL: nil,
            duration: nil,
            providerID: "direct",
            sourceID: id,
            isrc: nil,
            explicit: false,
            availableStreams: [stream],
            language: LanguageDetector.detect(declared: nil, texts: [title, displayArtist]),
            originalTitle: title,
            transliteratedTitle: RussianText.transliterate(title),
            license: license,
            licenseURL: licenseURL,
            attribution: stream.attribution,
            isStreamAllowed: format.isPlayableByAVPlayer,
            isDownloadAllowed: false,
            downloadURL: nil,
            sourcePageURL: nil,
            region: nil,
            genre: nil
        )
    }
}
