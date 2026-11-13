import Foundation

/// Jamendo Music Provider.
/// Документация: https://developer.jamendo.com/v3.0/docs
///
/// Используется только публичный Client ID. Client Secret в приложение не
/// попадает. Лицензия, разрешение на поток и разрешение на скачивание берутся
/// из ответа API для каждого трека отдельно.
actor JamendoProvider: MusicProvider {
    nonisolated let id = "jamendo"
    nonisolated let name = "Jamendo"

    nonisolated let capabilities = ProviderCapabilities(
        supportsSearch: true,
        supportsStreaming: true,
        supportsArtwork: true,
        supportsAlbums: true,
        supportsArtists: true,
        supportsLyrics: false,
        supportsDownload: true,
        requiresAuthentication: false,
        supportsRussian: true,
        isLocal: false
    )

    private let baseURL = "https://api.jamendo.com/v3.0"
    private let clientID = "b488b912"
    private let urlSession: URLSession

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpAdditionalHeaders = ["Accept": "application/json"]
        self.urlSession = URLSession(configuration: configuration)
    }

    // MARK: - MusicProvider

    func search(query: String, type: SearchType) async throws -> SearchResult {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return SearchResult(providerID: id)
        }

        var tracks: [Track] = []
        var albums: [Album] = []
        var artists: [Artist] = []

        if type == .track || type == .all {
            tracks = try await searchTracks(query: trimmed, limit: 40)
        }
        if type == .album || type == .all {
            albums = (try? await searchAlbums(query: trimmed, limit: 12)) ?? []
        }
        if type == .artist || type == .all {
            artists = (try? await searchArtists(query: trimmed, limit: 10)) ?? []
        }

        return SearchResult(
            tracks: tracks,
            albums: albums,
            artists: artists,
            providerID: id
        )
    }

    func resolveStream(for track: Track) async throws -> StreamSource? {
        guard track.providerID == id else {
            throw ProviderError.invalidConfiguration
        }
        return track.playableStreams.first
    }

    func fetchArtist(id artistID: String) async throws -> Artist? {
        let url = buildURL(
            endpoint: "/artists/",
            parameters: [
                "id": artistID,
                "imagesize": "600"
            ]
        )
        let response: JamendoResponse<JamendoArtist> = try await performRequest(url)
        guard let artist = response.results.first else {
            throw ProviderError.resourceNotFound
        }
        return mapArtist(artist)
    }

    func fetchAlbum(id albumID: String) async throws -> Album? {
        let url = buildURL(
            endpoint: "/albums/tracks",
            parameters: [
                "id": albumID,
                "imagesize": "600",
                "audioformat": "mp32",
                "include": "licenses musicinfo"
            ]
        )
        let response: JamendoResponse<JamendoAlbumWithTracks> = try await performRequest(url)
        guard let album = response.results.first else {
            throw ProviderError.resourceNotFound
        }
        let tracks = album.tracks.compactMap { mapTrack($0, albumName: album.name, artworkURL: album.image) }
        return Album(
            id: album.id,
            title: album.name,
            artist: album.artistName ?? "Неизвестный исполнитель",
            artworkURL: urlOrNil(album.image),
            releaseDate: parseDate(album.releaseDate),
            providerID: id,
            tracks: tracks
        )
    }

    // MARK: - Catalog discovery

    /// Загружает страницу каталога Jamendo для редакционных подборок.
    /// Это не поиск по запросу пользователя, а реальные релизы из открытого
    /// каталога с лицензией и прямым потоком.
    func discoveryTracks(
        language: String? = nil,
        tag: String? = nil,
        search: String? = nil,
        order: String = "popularity_month",
        offset: Int = 0,
        limit: Int = 100
    ) async throws -> [Track] {
        var parameters: [String: String] = [
            "limit": "\(min(max(limit, 1), 200))",
            "offset": "\(max(offset, 0))",
            "imagesize": "600",
            "audioformat": "mp32",
            "include": "licenses musicinfo",
            "order": order
        ]
        if let language, !language.isEmpty { parameters["lang"] = language }
        if let tag, !tag.isEmpty { parameters["tags"] = tag }
        if let search, !search.isEmpty { parameters["search"] = search }

        let url = buildURL(endpoint: "/tracks/", parameters: parameters)
        let response: JamendoResponse<JamendoTrack> = try await performRequest(url)
        return response.results.compactMap { mapTrack($0) }
    }

    /// Загружает исполнителей Jamendo для витрины «Исполнители».
    func discoveryArtists(
        order: String = "popularity_month",
        offset: Int = 0,
        limit: Int = 100
    ) async throws -> [Artist] {
        let url = buildURL(
            endpoint: "/artists/",
            parameters: [
                "limit": "\(min(max(limit, 1), 200))",
                "offset": "\(max(offset, 0))",
                "imagesize": "600",
                "order": order
            ]
        )
        let response: JamendoResponse<JamendoArtist> = try await performRequest(url)
        return response.results.map(mapArtist)
    }

    func healthCheck() async -> ProviderHealth {
        let start = ContinuousClock.now
        do {
            let url = buildURL(
                endpoint: "/tracks/",
                parameters: [
                    "limit": "1",
                    "audioformat": "mp32",
                    "include": "licenses"
                ]
            )
            let response: JamendoResponse<JamendoTrack> = try await performRequest(url)
            let latency = start.duration(to: .now).timeInterval
            return ProviderHealth(
                isAvailable: response.headers?.status != "failed",
                latency: latency,
                message: response.headers?.status == "failed"
                    ? (response.headers?.errorMessage ?? "API вернул ошибку")
                    : "API отвечает",
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

    // MARK: - Search endpoints

    private func searchTracks(query: String, limit: Int) async throws -> [Track] {
        var parameters = [
            "search": query,
            "limit": "\(limit)",
            "offset": "0",
            "imagesize": "600",
            "audioformat": "mp32",
            "include": "licenses musicinfo",
            "order": "relevance"
        ]
        // Jamendo ищет по метаданным на языке записи. Для кириллического
        // запроса фильтр lang=ru даёт русскоязычные треки, иначе API часто
        // возвращает пустую выдачу.
        if RussianText.hasCyrillic(query) {
            parameters["lang"] = "ru"
        }
        let url = buildURL(endpoint: "/tracks/", parameters: parameters)
        let response: JamendoResponse<JamendoTrack> = try await performRequest(url)
        return response.results.compactMap { mapTrack($0) }
    }

    private func searchAlbums(query: String, limit: Int) async throws -> [Album] {
        let url = buildURL(
            endpoint: "/albums/",
            parameters: [
                "search": query,
                "limit": "\(limit)",
                "imagesize": "600",
                "order": "relevance"
            ]
        )
        let response: JamendoResponse<JamendoAlbum> = try await performRequest(url)
        return response.results.map { album in
            Album(
                id: album.id,
                title: album.name,
                artist: album.artistName ?? "Неизвестный исполнитель",
                artworkURL: urlOrNil(album.image),
                releaseDate: parseDate(album.releaseDate),
                providerID: id,
                tracks: []
            )
        }
    }

    private func searchArtists(query: String, limit: Int) async throws -> [Artist] {
        let url = buildURL(
            endpoint: "/artists/",
            parameters: [
                "search": query,
                "limit": "\(limit)",
                "imagesize": "600",
                "order": "relevance"
            ]
        )
        let response: JamendoResponse<JamendoArtist> = try await performRequest(url)
        return response.results.map(mapArtist)
    }

    // MARK: - Mapping

    private func mapTrack(
        _ data: JamendoTrack,
        albumName: String? = nil,
        artworkURL: String? = nil
    ) -> Track? {
        guard let audioString = data.audio, !audioString.isEmpty,
              let audioURL = URL(string: audioString) else {
            return nil
        }

        let license = LicenseParser.parse(urlString: data.licenseCCURL)
        let licenseURL = URL(string: data.licenseCCURL ?? "")
            ?? LicenseParser.defaultURL(for: license)
        let downloadURL = data.audiodownloadAllowed == true
            ? urlOrNil(data.audiodownload)
            : nil
        let isDownloadAllowed = data.audiodownloadAllowed == true && downloadURL != nil

        let title = cleanText(data.name)
        let language = LanguageDetector.detect(
            declared: data.musicinfo?.lang,
            texts: [title, data.artistName, data.albumName ?? albumName]
        )
        let genre = data.musicinfo?.tags?.genres?.first(where: { !$0.isEmpty })
        let artistName = cleanText(data.artistName ?? "Неизвестный исполнитель")
        let albumTitle = cleanText(albumName ?? data.albumName)
        let artwork = urlOrNil(data.image ?? data.albumImage ?? artworkURL)

        let attribution = [
            "«\(title)» — \(artistName)",
            albumTitle.map { "альбом «\($0)»" },
            "источник: Jamendo",
            "лицензия: \(license.displayName)"
        ].compactMap { $0 }.joined(separator: ", ")

        let stream = StreamSource(
            providerID: id,
            streamURL: audioURL,
            format: .mp3,
            bitrate: nil,
            availability: .available,
            license: license,
            licenseURL: licenseURL,
            attribution: attribution
        )

        return Track(
            id: "\(id)_\(data.id)",
            title: title,
            artist: artistName,
            album: albumTitle,
            artworkURL: artwork,
            duration: data.duration.map(TimeInterval.init),
            providerID: id,
            sourceID: data.id,
            isrc: nil,
            explicit: false,
            availableStreams: [stream],
            language: language,
            originalTitle: title,
            transliteratedTitle: LanguageDetector.isCyrillic(title) ? RussianText.transliterate(title) : nil,
            license: license,
            licenseURL: licenseURL,
            attribution: attribution,
            isStreamAllowed: true,
            isDownloadAllowed: isDownloadAllowed,
            downloadURL: downloadURL,
            sourcePageURL: urlOrNil(data.shareurl) ?? URL(string: "https://www.jamendo.com/track/\(data.id)"),
            region: nil,
            genre: genre,
            releaseDate: parseDate(data.releaseDate),
            trackNumber: data.trackNumber ?? data.position,
            albumID: data.albumID
        )
    }

    private func mapArtist(_ data: JamendoArtist) -> Artist {
        Artist(
            id: data.id,
            name: data.name,
            artworkURL: urlOrNil(data.image),
            biography: data.website,
            providerID: id
        )
    }

    // MARK: - Networking

    private func buildURL(endpoint: String, parameters: [String: String]) -> URL {
        var components = URLComponents(string: baseURL + endpoint)!
        var items = [URLQueryItem(name: "client_id", value: clientID)]
        items.append(URLQueryItem(name: "format", value: "json"))
        for key in parameters.keys.sorted() {
            items.append(URLQueryItem(name: key, value: parameters[key]))
        }
        components.queryItems = items
        return components.url!
    }

    private func performRequest<T: Decodable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("VOLNA/1.0 (iOS; open music player)", forHTTPHeaderField: "User-Agent")
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
            let decoder = JSONDecoder()
            do {
                let decoded = try decoder.decode(T.self, from: data)
                if let jamendoResponse = decoded as? JamendoErrorReporting,
                   jamendoResponse.jamendoStatus == "failed" {
                    throw ProviderError.invalidResponse(jamendoResponse.jamendoErrorMessage)
                }
                return decoded
            } catch let error as ProviderError {
                throw error
            } catch {
                throw ProviderError.invalidResponse("не удалось разобрать JSON Jamendo")
            }
        case 401, 403:
            throw ProviderError.authenticationRequired
        case 429:
            throw ProviderError.rateLimitExceeded
        case 404:
            throw ProviderError.resourceNotFound
        default:
            throw ProviderError.invalidResponse("HTTP \(http.statusCode)")
        }
    }

    private func cleanText(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func urlOrNil(_ string: String?) -> URL? {
        guard let string, !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return URL(string: string)
    }

    private func parseDate(_ string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }
}

// MARK: - API models

private protocol JamendoErrorReporting {
    var jamendoStatus: String? { get }
    var jamendoErrorMessage: String? { get }
}

private struct JamendoResponse<Result: Decodable>: Decodable, JamendoErrorReporting {
    let headers: JamendoHeaders?
    let results: [Result]

    var jamendoStatus: String? { headers?.status }
    var jamendoErrorMessage: String? { headers?.errorMessage }
}

private struct JamendoHeaders: Decodable {
    let status: String?
    let code: Int?
    let errorMessage: String?
    let warnings: String?
    let resultsCount: Int?

    enum CodingKeys: String, CodingKey {
        case status
        case code
        case errorMessage = "error_message"
        case warnings
        case resultsCount = "results_count"
    }
}

private struct JamendoMusicInfo: Decodable {
    let vocalInstrumental: String?
    let lang: String?
    let gender: String?
    let acousticelectric: String?
    let speed: String?
    let tags: JamendoTags?

    enum CodingKeys: String, CodingKey {
        case vocalInstrumental = "vocalinstrumental"
        case lang
        case gender
        case acousticelectric
        case speed
        case tags
    }
}

private struct JamendoTags: Decodable {
    let genres: [String]?
    let instruments: [String]?
    let vartags: [String]?
}

private struct JamendoTrack: Decodable {
    let id: String
    let name: String
    let duration: Int?
    let artistName: String?
    let albumName: String?
    let albumImage: String?
    let albumID: String?
    let image: String?
    let audio: String?
    let audiodownload: String?
    let audiodownloadAllowed: Bool?
    let licenseCCURL: String?
    let shareurl: String?
    let releaseDate: String?
    let position: Int?
    let trackNumber: Int?
    let musicinfo: JamendoMusicInfo?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case duration
        case artistName = "artist_name"
        case albumName = "album_name"
        case albumImage = "album_image"
        case albumID = "album_id"
        case image
        case audio
        case audiodownload
        case audiodownloadAllowed = "audiodownload_allowed"
        case licenseCCURL = "license_ccurl"
        case shareurl
        case releaseDate = "releasedate"
        case position
        case trackNumber = "track_number"
        case musicinfo
    }
}

private struct JamendoArtist: Decodable {
    let id: String
    let name: String
    let image: String?
    let website: String?
    let shorturl: String?
}

private struct JamendoAlbum: Decodable {
    let id: String
    let name: String
    let artistName: String?
    let image: String?
    let releaseDate: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case artistName = "artist_name"
        case image
        case releaseDate = "releasedate"
    }
}

private struct JamendoAlbumWithTracks: Decodable {
    let id: String
    let name: String
    let artistName: String?
    let image: String?
    let releaseDate: String?
    let tracks: [JamendoTrack]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case artistName = "artist_name"
        case image
        case releaseDate = "releasedate"
        case tracks
    }
}
