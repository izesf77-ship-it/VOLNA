import Foundation

/// Openverse — открытый поисковый индекс Creative Commons аудио.
/// Документация: https://api.openverse.org/v1/
///
/// VOLNA использует Openverse как дополнительный агрегатор и оставляет только
/// записи с прямой аудиоссылкой и известной лицензией. Анонимный лимит —
/// 20 запросов в минуту и 200 в сутки на IP, поэтому источник не используется
/// для фоновых подборок на главной.
actor OpenverseProvider: MusicProvider {
    nonisolated let id = "openverse"
    nonisolated let name = "Openverse"

    nonisolated let capabilities = ProviderCapabilities(
        supportsSearch: true,
        supportsStreaming: true,
        supportsArtwork: true,
        supportsAlbums: false,
        supportsArtists: false,
        supportsLyrics: false,
        supportsDownload: false,
        requiresAuthentication: false,
        supportsRussian: true,
        isLocal: false
    )

    private let baseURL = "https://api.openverse.org/v1/audio/"
    private let urlSession: URLSession

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.httpAdditionalHeaders = ["Accept": "application/json"]
        self.urlSession = URLSession(configuration: configuration)
    }

    func search(query: String, type: SearchType) async throws -> SearchResult {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, type == .track || type == .all else {
            return SearchResult(providerID: id)
        }

        let url = try buildURL(query: trimmed)
        let response: OpenverseResponse = try await performRequest(url)

        var tracks: [Track] = []
        for result in response.results {
            if let track = mapResult(result) {
                tracks.append(track)
            }
        }
        return SearchResult(tracks: Array(tracks.prefix(25)), providerID: id)
    }

    func resolveStream(for track: Track) async throws -> StreamSource? {
        guard track.providerID == id else {
            throw ProviderError.invalidConfiguration
        }
        return track.playableStreams.first
    }

    func healthCheck() async -> ProviderHealth {
        let start = ContinuousClock.now
        do {
            let url = try buildURL(query: "music", pageSize: 1)
            let response: OpenverseResponse = try await performRequest(url)
            let latency = start.duration(to: .now).timeInterval
            return ProviderHealth(
                isAvailable: !response.results.isEmpty,
                latency: latency,
                message: "Openverse API отвечает",
                sampleTrackCount: response.results.count
            )
        } catch {
            return ProviderHealth(
                isAvailable: false,
                latency: nil,
                message: error.localizedDescription,
                sampleTrackCount: nil
            )
        }
    }

    private func mapResult(_ result: OpenverseAudio) -> Track? {
        guard let title = result.title?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty,
              let urlString = result.url,
              let streamURL = URL(string: urlString),
              streamURL.scheme?.lowercased() == "https" else {
            return nil
        }

        let mime = contentType(for: result)
        let format = AudioFormat.from(mimeType: mime, pathExtension: streamURL.pathExtension)
        guard format != .unknown else { return nil }

        let license = LicenseParser.parse(identifier: result.license, version: result.licenseVersion)
        guard license.isKnownOpenLicense else { return nil }

        let licenseURL = URL(string: result.licenseURL ?? "")
            ?? LicenseParser.defaultURL(for: license)
        let artist = result.creator?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty ?? "Неизвестный исполнитель"
        let duration = result.duration.map { TimeInterval($0) / 1000.0 }
        let language = LanguageDetector.detect(declared: nil, texts: [title, artist, result.genres?.first?.name])
        let providerName = result.provider ?? result.source ?? "Openverse"

        let attribution = [
            "«\(title)» — \(artist)",
            "источник: \(providerName) через Openverse",
            "лицензия: \(license.displayName)"
        ].joined(separator: ", ")

        let stream = StreamSource(
            providerID: id,
            streamURL: streamURL,
            format: format,
            bitrate: result.bitRate,
            availability: format.isPlayableByAVPlayer ? .available : .unavailable,
            license: license,
            licenseURL: licenseURL,
            attribution: attribution
        )

        return Track(
            id: "\(id)_\(result.id)",
            title: title,
            artist: artist,
            album: result.album?.nilIfEmpty,
            artworkURL: URL(string: result.thumbnail ?? ""),
            duration: duration,
            providerID: id,
            sourceID: result.id,
            isrc: nil,
            explicit: result.mature ?? false,
            availableStreams: [stream],
            language: language,
            originalTitle: title,
            transliteratedTitle: LanguageDetector.isCyrillic(title)
                ? RussianText.transliterate(title)
                : nil,
            license: license,
            licenseURL: licenseURL,
            attribution: attribution,
            isStreamAllowed: true,
            isDownloadAllowed: false,
            downloadURL: nil,
            sourcePageURL: URL(string: result.foreignLandingURL ?? ""),
            region: nil,
            genre: result.genres?.first?.name
        )
    }

    private func contentType(for result: OpenverseAudio) -> String? {
        if let filetype = result.filetype?.lowercased(), !filetype.isEmpty {
            switch filetype {
            case "mp3", "mp32": return "audio/mpeg"
            case "m4a", "mp4": return "audio/mp4"
            case "aac": return "audio/aac"
            case "flac": return "audio/flac"
            case "wav": return "audio/wav"
            case "ogg", "oga": return "audio/ogg"
            case "opus": return "audio/opus"
            default: break
            }
        }
        return result.mimeType
    }

    private func buildURL(query: String, pageSize: Int = 20) throws -> URL {
        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "page_size", value: "\(pageSize)"),
            URLQueryItem(name: "source", value: "jamendo,wikimedia_audio")
        ]
        guard let url = components?.url else {
            throw ProviderError.invalidConfiguration
        }
        return url
    }

    private func performRequest<T: Decodable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue(
            "VOLNA/1.0 (iOS; open music player; https://github.com/izesf77-ship-it/VOLNA)",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            if Task.isCancelled { throw CancellationError() }
            throw ProviderError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.invalidResponse()
        }
        switch http.statusCode {
        case 200:
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw ProviderError.invalidResponse("не удалось разобрать ответ Openverse")
            }
        case 400:
            throw ProviderError.invalidResponse("Openverse отклонил параметры запроса")
        case 429:
            throw ProviderError.rateLimitExceeded
        case 404:
            throw ProviderError.resourceNotFound
        default:
            throw ProviderError.invalidResponse("HTTP \(http.statusCode)")
        }
    }
}

// MARK: - API models

private struct OpenverseResponse: Decodable {
    let resultCount: Int?
    let results: [OpenverseAudio]

    enum CodingKeys: String, CodingKey {
        case resultCount = "result_count"
        case results
    }
}

private struct OpenverseAudio: Decodable {
    let id: String
    let title: String?
    let creator: String?
    let url: String?
    let thumbnail: String?
    let duration: Int?
    let license: String?
    let licenseVersion: String?
    let licenseURL: String?
    let foreignLandingURL: String?
    let provider: String?
    let source: String?
    let filetype: String?
    let bitRate: Int?
    let sampleRate: Int?
    let genres: [OpenverseGenre]?
    let album: String?
    let mimeType: String?
    let mature: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case creator
        case url
        case thumbnail
        case duration
        case license
        case licenseVersion = "license_version"
        case licenseURL = "license_url"
        case foreignLandingURL = "foreign_landing_url"
        case provider
        case source
        case filetype
        case bitRate = "bit_rate"
        case sampleRate = "sample_rate"
        case genres
        case album
        case mimeType = "mime_type"
        case mature
    }
}

private struct OpenverseGenre: Decodable {
    let name: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            name = string
            return
        }
        if let object = try? container.decode(OpenverseGenreObject.self) {
            name = object.name
            return
        }
        name = nil
    }
}

private struct OpenverseGenreObject: Decodable {
    let name: String?
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
