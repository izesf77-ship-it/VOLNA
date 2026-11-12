import Foundation

/// Wikimedia Commons Audio Provider.
/// Документация: https://www.mediawiki.org/wiki/API:Main_page
///
/// Для OGG/Opus используется официальная MP3-транскодия Wikimedia
/// (`prop=videoinfo`, `viprop=derivatives`), поскольку AVPlayer не умеет
/// воспроизводить OGG/Opus без стороннего декодера. Лицензия и атрибуция
/// берутся из `extmetadata` для каждого файла.
actor WikimediaCommonsProvider: MusicProvider {
    nonisolated let id = "wikimedia_commons"
    nonisolated let name = "Wikimedia Commons"

    nonisolated let capabilities = ProviderCapabilities(
        supportsSearch: true,
        supportsStreaming: true,
        supportsArtwork: false,
        supportsAlbums: false,
        supportsArtists: false,
        supportsLyrics: false,
        supportsDownload: true,
        requiresAuthentication: false,
        supportsRussian: true,
        isLocal: false
    )

    private let baseURL = "https://commons.wikimedia.org/w/api.php"
    private let urlSession: URLSession

    private let spokenWordMarkers = [
        "pronunciation", "pronounciation", "spoken", "speech", "voice recording",
        "reading", "recitation", "wiki-", "wiktionary", "dialogue", "interview",
        "произношение", "озвучка", "чтение", "лекция", "интервью", "аудиокнига"
    ]

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 25
        configuration.timeoutIntervalForResource = 40
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.httpAdditionalHeaders = ["Accept": "application/json"]
        self.urlSession = URLSession(configuration: configuration)
    }

    // MARK: - MusicProvider

    func search(query: String, type: SearchType) async throws -> SearchResult {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return SearchResult(providerID: id) }
        guard type == .track || type == .all else {
            return SearchResult(providerID: id)
        }

        let tracks = try await searchFiles(query: trimmed)
        return SearchResult(tracks: tracks, providerID: id)
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
            let url = try buildSearchURL(query: "music", limit: 1)
            let response: WikimediaResponse = try await performRequest(url)
            let pages = response.query?.pages.map { Array($0.values) } ?? []
            let latency = start.duration(to: .now).timeInterval
            return ProviderHealth(
                isAvailable: !pages.isEmpty,
                latency: latency,
                message: "MediaWiki API отвечает",
                sampleTrackCount: pages.count
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

    // MARK: - Search

    private func searchFiles(query: String) async throws -> [Track] {
        let url = try buildSearchURL(query: query, limit: 25)
        let response: WikimediaResponse = try await performRequest(url)

        let pages = response.query?.pages?.values.sorted {
            ($0.index ?? Int.max) < ($1.index ?? Int.max)
        } ?? []

        var seen = Set<String>()
        var tracks: [Track] = []

        for page in pages {
            guard let track = mapPage(page), seen.insert(track.id).inserted else {
                continue
            }
            tracks.append(track)
        }

        return Array(tracks.prefix(30))
    }

    private func mapPage(_ page: WikimediaPage) -> Track? {
        guard let pageID = page.pageid,
              let info = page.videoinfo?.first ?? page.imageinfo?.first else {
            return nil
        }

        let rawTitle = page.title ?? ""
        guard !rawTitle.isEmpty else { return nil }

        let lowerTitle = rawTitle.lowercased()
        guard !spokenWordMarkers.contains(where: { lowerTitle.contains($0) }) else {
            return nil
        }

        let meta = info.extmetadata ?? [:]
        let cleanTitle = displayTitle(from: rawTitle, meta: meta)
        guard !cleanTitle.isEmpty else { return nil }

        let licenseURLString = firstNonEmpty([
            meta["LicenseUrl"]?.stringValue,
            meta["License"]?.stringValue
        ])
        var license = LicenseParser.parse(urlString: licenseURLString)
        if license == .unknown {
            license = LicenseParser.parse(text: firstNonEmpty([
                meta["LicenseShortName"]?.stringValue,
                meta["UsageTerms"]?.stringValue
            ]))
        }

        let licenseURL = URL(string: licenseURLString ?? "")
            ?? LicenseParser.defaultURL(for: license)

        let artist = firstNonEmpty([
            stripHTML(meta["Artist"]?.stringValue),
            stripHTML(meta["Credit"]?.stringValue),
            "Wikimedia Commons"
        ]) ?? "Wikimedia Commons"

        let description = stripHTML(meta["ImageDescription"]?.stringValue)
        let genre = firstNonEmpty([
            meta["Genre"]?.stringValue,
            meta["ObjectName"]?.stringValue
        ])

        let pageURL = URL(string: info.descriptionurl ?? "")
            ?? URL(string: "https://commons.wikimedia.org/wiki/\(rawTitle.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? rawTitle)")

        let duration = info.duration.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        let language = LanguageDetector.detect(
            declared: nil,
            texts: [cleanTitle, artist, description]
        )

        guard let stream = selectStream(info: info, license: license, licenseURL: licenseURL) else {
            return nil
        }

        let attribution = [
            "«\(cleanTitle)» — \(artist)",
            "источник: Wikimedia Commons",
            "лицензия: \(license.displayName)"
        ].joined(separator: ", ")

        return Track(
            id: "\(id)_\(pageID)",
            title: cleanTitle,
            artist: artist,
            album: nil,
            artworkURL: nil,
            duration: duration,
            providerID: id,
            sourceID: String(pageID),
            isrc: nil,
            explicit: false,
            availableStreams: [stream],
            language: language,
            originalTitle: cleanTitle,
            transliteratedTitle: LanguageDetector.isCyrillic(cleanTitle)
                ? RussianText.transliterate(cleanTitle)
                : nil,
            license: license,
            licenseURL: licenseURL,
            attribution: attribution,
            isStreamAllowed: true,
            isDownloadAllowed: true,
            downloadURL: stream.streamURL,
            sourcePageURL: pageURL,
            region: nil,
            genre: genre
        )
    }

    // MARK: - Stream selection

    private func selectStream(
        info: WikimediaVideoInfo,
        license: LicenseType,
        licenseURL: URL?
    ) -> StreamSource? {
        let derivatives = info.derivatives ?? []
        if let mp3 = derivatives.first(where: { derivative in
            let type = derivative.type?.lowercased() ?? ""
            return type.contains("audio/mpeg") && derivative.src?.isEmpty == false
        }), let string = mp3.src, let url = URL(string: string) {
            return StreamSource(
                providerID: id,
                streamURL: url,
                format: .mp3,
                bitrate: nil,
                availability: .available,
                license: license,
                licenseURL: licenseURL,
                attribution: "Wikimedia Commons, MP3-транскодия"
            )
        }

        if let mime = info.mime?.lowercased(),
           mime == "audio/mpeg",
           let string = info.url,
           let url = URL(string: string) {
            return StreamSource(
                providerID: id,
                streamURL: url,
                format: .mp3,
                bitrate: nil,
                availability: .available,
                license: license,
                licenseURL: licenseURL,
                attribution: "Wikimedia Commons, исходный MP3"
            )
        }

        // Официальной MP3-транскодии нет: файл помечается недоступным для
        // AVPlayer, но остаётся видимым в метаданных с честным форматом.
        if let string = info.url, let url = URL(string: string) {
            let format = AudioFormat.from(mimeType: info.mime, pathExtension: url.pathExtension)
            guard format != .unknown else { return nil }
            return StreamSource(
                providerID: id,
                streamURL: url,
                format: format,
                bitrate: nil,
                availability: format.isPlayableByAVPlayer ? .available : .unavailable,
                license: license,
                licenseURL: licenseURL,
                attribution: "Wikimedia Commons, исходный файл без MP3-транскодии"
            )
        }

        return nil
    }

    // MARK: - Networking

    private func buildSearchURL(query: String, limit: Int) throws -> URL {
        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "generator", value: "search"),
            URLQueryItem(name: "gsrsearch", value: "filetype:audio \(query)"),
            URLQueryItem(name: "gsrnamespace", value: "6"),
            URLQueryItem(name: "gsrlimit", value: "\(limit)"),
            URLQueryItem(name: "prop", value: "videoinfo"),
            URLQueryItem(name: "viprop", value: "url|size|mime|extmetadata|derivatives|dimensions"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "formatversion", value: "1")
        ]
        guard let url = components?.url else {
            throw ProviderError.invalidConfiguration
        }
        return url
    }

    private func performRequest<T: Decodable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.timeoutInterval = 25
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
                throw ProviderError.invalidResponse("не удалось разобрать ответ Wikimedia")
            }
        case 429:
            throw ProviderError.rateLimitExceeded
        case 404:
            throw ProviderError.resourceNotFound
        default:
            throw ProviderError.invalidResponse("HTTP \(http.statusCode)")
        }
    }

    // MARK: - Text helpers

    private func displayTitle(
        from rawTitle: String,
        meta: [String: WikimediaMetaValue]
    ) -> String {
        if let objectName = firstNonEmpty([
            meta["ObjectName"]?.stringValue,
            meta["Title"]?.stringValue
        ]) {
            return objectName
        }

        var title = rawTitle
        if title.lowercased().hasPrefix("file:") {
            title = String(title.dropFirst(5))
        }
        title = (title as NSString).deletingPathExtension
        title = title.replacingOccurrences(of: "_", with: " ")
        return title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func stripHTML(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        var text = value
            .replacingOccurrences(of: "<br />", with: " ")
            .replacingOccurrences(of: "<br/>", with: " ")
            .replacingOccurrences(of: "<br>", with: " ")
        text = text.replacingOccurrences(
            of: "<[^>]+>",
            with: " ",
            options: .regularExpression
        )
        text = text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
        text = text
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        return text.isEmpty ? nil : text
    }

    private func firstNonEmpty(_ values: [String?]) -> String? {
        for value in values {
            if let value {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return nil
    }
}

// MARK: - API models

private struct WikimediaResponse: Decodable {
    let query: WikimediaQuery?
}

private struct WikimediaQuery: Decodable {
    let pages: [String: WikimediaPage]?
}

private struct WikimediaPage: Decodable {
    let pageid: Int?
    let title: String?
    let index: Int?
    let videoinfo: [WikimediaVideoInfo]?
    let imageinfo: [WikimediaVideoInfo]?
}

private struct WikimediaVideoInfo: Decodable {
    let url: String?
    let descriptionurl: String?
    let mime: String?
    let duration: Double?
    let extmetadata: [String: WikimediaMetaValue]?
    let derivatives: [WikimediaDerivative]?
}

private struct WikimediaDerivative: Decodable {
    let src: String?
    let type: String?
}

private struct WikimediaMetaValue: Decodable {
    let value: WikimediaFlexibleString?

    var stringValue: String? {
        value?.value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let dictionary = try? container.decode([String: WikimediaFlexibleString].self) {
            value = dictionary["value"]
            return
        }
        value = try? container.decode(WikimediaFlexibleString.self)
    }
}

private struct WikimediaFlexibleString: Decodable {
    let value: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = nil
            return
        }
        if let string = try? container.decode(String.self) {
            value = string
            return
        }
        if let int = try? container.decode(Int.self) {
            value = String(int)
            return
        }
        if let double = try? container.decode(Double.self) {
            value = String(double)
            return
        }
        value = nil
    }
}
