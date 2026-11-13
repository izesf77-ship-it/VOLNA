import Foundation

/// Audius public API provider.
/// Docs: https://docs.audius.co/api/
///
/// Uses official discovery endpoints with `app_name`. Audius tracks are
/// user-uploaded; availability/licensing/stream permissions are taken from API
/// fields per track. Some tracks may disallow API streaming or be unavailable.
actor AudiusProvider: MusicProvider {
    nonisolated let id = "audius"
    nonisolated let name = "Audius"

    nonisolated let capabilities = ProviderCapabilities(
        supportsSearch: true,
        supportsStreaming: true,
        supportsArtwork: true,
        supportsAlbums: false,
        supportsArtists: true,
        supportsLyrics: false,
        supportsDownload: false,
        requiresAuthentication: false,
        supportsRussian: true,
        isLocal: false
    )

    private let appName = "VOLNA"
    private let bootstrapURL = URL(string: "https://api.audius.co")!
    private let fallbackHosts = [
        "https://discoveryprovider.audius.co",
        "https://discoveryprovider2.audius.co",
        "https://discoveryprovider3.audius.co"
    ]

    private var selectedHost: String?
    private var hostCacheExpiresAt: Date = .distantPast
    private var lastSearchAt: Date = .distantPast
    private let minSearchInterval: TimeInterval = 0.25
    private var blockedUntil: Date = .distantPast
    private var consecutiveFailures: Int = 0

    private let urlSession: URLSession
    private let decoder = JSONDecoder()

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 35
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpAdditionalHeaders = ["Accept": "application/json"]
        self.urlSession = URLSession(configuration: configuration)
    }

    // MARK: - MusicProvider

    func search(query: String, type: SearchType) async throws -> SearchResult {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return SearchResult(providerID: id) }
        try await enforceRateLimit()

        var tracks: [Track] = []
        var artists: [Artist] = []

        if type == .track || type == .all {
            tracks = try await searchTracks(query: trimmed, limit: 30)
        }
        if type == .artist || type == .all {
            artists = (try? await searchArtists(query: trimmed, limit: 12)) ?? []
        }

        return SearchResult(tracks: tracks, albums: [], artists: artists, providerID: id)
    }

    func resolveStream(for track: Track) async throws -> StreamSource? {
        guard track.providerID == id else { throw ProviderError.invalidConfiguration }
        // Audius stream endpoint may redirect; URL is stable per track id.
        return track.playableStreams.first
    }

    func fetchArtist(id artistID: String) async throws -> Artist? {
        let path = "/v1/users/\(artistID)"
        let response: AudiusUserResponse = try await request(path: path, queryItems: [])
        return response.data.map(mapUser)
    }

    func healthCheck() async -> ProviderHealth {
        let start = ContinuousClock.now
        do {
            let tracks = try await trendingTracks(limit: 1, time: "week")
            let latency = start.duration(to: .now).timeInterval
            return ProviderHealth(
                isAvailable: !tracks.isEmpty,
                latency: latency,
                message: tracks.isEmpty ? "API ответил без треков" : "API отвечает",
                sampleTrackCount: tracks.count
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

    // MARK: - Audius-specific discovery

    func searchTracks(query: String, limit: Int = 30) async throws -> [Track] {
        let items: [String: String] = [
            "query": query,
            "limit": "\(min(max(limit, 1), 50))"
        ]
        let response: AudiusTracksResponse = try await request(path: "/v1/tracks/search", queryItems: queryItems(items))
        return response.data.compactMap { mapTrack($0) }
    }

    func trendingTracks(limit: Int = 40, time: String = "week") async throws -> [Track] {
        let items: [String: String] = [
            "limit": "\(min(max(limit, 1), 100))",
            "time": time
        ]
        let response: AudiusTracksResponse = try await request(path: "/v1/tracks/trending", queryItems: queryItems(items))
        return response.data.compactMap { mapTrack($0) }
    }

    func latestTracks(limit: Int = 40) async throws -> [Track] {
        // Audius exposes trending/underground/recommended flows; "latest" is approximated
        // via recent trending and search fallbacks at catalog layer.
        return try await trendingTracks(limit: limit, time: "month")
    }

    func fetchTrack(id trackID: String) async throws -> Track? {
        let response: AudiusTrackResponse = try await request(path: "/v1/tracks/\(trackID)", queryItems: [])
        return response.data.flatMap { mapTrack($0) }
    }

    func fetchPlaylists(for userID: String, limit: Int = 20) async throws -> [Album] {
        let response: AudiusPlaylistsResponse = try await request(
            path: "/v1/users/\(userID)/playlists",
            queryItems: queryItems(["limit": "\(min(max(limit, 1), 50))"])
        )
        return response.data.compactMap { mapPlaylist($0) }
    }

    private func searchArtists(query: String, limit: Int) async throws -> [Artist] {
        let response: AudiusUsersResponse = try await request(
            path: "/v1/users/search",
            queryItems: queryItems(["query": query, "limit": "\(min(max(limit, 1), 30))"])
        )
        return response.data.map(mapUser)
    }

    // MARK: - Networking

    private func enforceRateLimit() async throws {
        if Date() < blockedUntil {
            throw ProviderError.invalidResponse("Audius временно недоступен (повторная проверка позже)")
        }
        let delta = Date().timeIntervalSince(lastSearchAt)
        if delta < minSearchInterval {
            let ns = UInt64((minSearchInterval - delta) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: ns)
        }
        lastSearchAt = Date()
    }

    private func request<T: Decodable>(path: String, queryItems: [URLQueryItem], attempt: Int = 0) async throws -> T {
        if Task.isCancelled { throw CancellationError() }
        if Date() < blockedUntil {
            throw ProviderError.invalidResponse("Audius временно недоступен (повторная проверка позже)")
        }
        let host = try await resolveHost()
        guard let url = buildURL(host: host, path: path, queryItems: queryItems) else {
            throw ProviderError.invalidConfiguration
        }

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
            consecutiveFailures += 1
            if attempt < 1 {
                invalidateHostCache()
                return try await self.request(path: path, queryItems: queryItems, attempt: attempt + 1)
            }
            if consecutiveFailures >= 3 { blockedUntil = Date().addingTimeInterval(10 * 60) }
            throw ProviderError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            consecutiveFailures += 1
            throw ProviderError.invalidResponse()
        }
        switch http.statusCode {
        case 200:
            consecutiveFailures = 0
            blockedUntil = .distantPast
            do { return try decoder.decode(T.self, from: data) }
            catch { throw ProviderError.invalidResponse("не удалось разобрать JSON Audius") }
        case 429:
            blockedUntil = Date().addingTimeInterval(2 * 60)
            throw ProviderError.rateLimitExceeded
        case 403:
            consecutiveFailures += 1
            blockedUntil = Date().addingTimeInterval(consecutiveFailures >= 2 ? 30 * 60 : 10 * 60)
            throw ProviderError.invalidResponse("HTTP 403 (возможна Cloudflare-блокировка)")
        case 404:
            throw ProviderError.resourceNotFound
        case 500...599 where attempt < 1:
            invalidateHostCache()
            try? await Task.sleep(nanoseconds: 300_000_000)
            return try await self.request(path: path, queryItems: queryItems, attempt: attempt + 1)
        default:
            consecutiveFailures += 1
            if attempt < 1 {
                invalidateHostCache()
                return try await self.request(path: path, queryItems: queryItems, attempt: attempt + 1)
            }
            if consecutiveFailures >= 3 { blockedUntil = Date().addingTimeInterval(10 * 60) }
            throw ProviderError.invalidResponse("HTTP \(http.statusCode)")
        }
    }

    private func buildURL(host: String, path: String, queryItems: [URLQueryItem]) -> URL? {
        var components = URLComponents(string: host + path)
        var items = [URLQueryItem(name: "app_name", value: appName)]
        items.append(contentsOf: queryItems)
        components?.queryItems = items
        return components?.url
    }

    private func queryItems(_ items: [String: String]) -> [URLQueryItem] {
        items.keys.sorted().map { URLQueryItem(name: $0, value: items[$0]) }
    }

    private func resolveHost() async throws -> String {
        if let selectedHost, Date() < hostCacheExpiresAt { return selectedHost }
        for candidate in ([try? await fetchBootstrapHost()].compactMap { $0 } + fallbackHosts) {
            selectedHost = candidate
            hostCacheExpiresAt = Date().addingTimeInterval(10 * 60)
            return candidate
        }
        throw ProviderError.invalidConfiguration
    }

    private func fetchBootstrapHost() async throws -> String? {
        var request = URLRequest(url: bootstrapURL)
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
        let decoded = try decoder.decode(AudiusBootstrapResponse.self, from: data)
        return decoded.data?.first
    }

    private func invalidateHostCache() {
        selectedHost = nil
        hostCacheExpiresAt = .distantPast
    }

    // MARK: - Mapping

    private func mapTrack(_ data: AudiusTrack) -> Track? {
        let id = data.id
        guard !id.isEmpty else { return nil }
        guard data.isStreamable != false else { return nil }
        if data.streamConditions != nil && data.isStreamable == false { return nil }

        let title = clean(data.title)
        let artist = clean(data.user?.name ?? data.user?.handle ?? "Неизвестный исполнитель")
        guard !title.isEmpty else { return nil }

        guard let streamURL = URL(string: "https://api.audius.co/v1/tracks/\(id)/stream?app_name=\(appName)") else {
            return nil
        }

        let duration = data.duration.map(TimeInterval.init)
        let artwork = bestArtwork(for: data)
        let releaseDate = parseDate(data.releaseDate) ?? parseTimestamp(data.releaseDateMs)
        let language = LanguageDetector.detect(declared: nil, texts: [title, artist, data.genre, data.mood])
        let sourcePage = URL(string: data.permalink.map { "https://audius.co\($0)" } ?? "https://audius.co/tracks/\(id)")
        let attribution = "«\(title)» — \(artist), источник: Audius"

        // Audius does not expose a universal Creative Commons license for every track.
        // Keep license unknown unless explicitly provided by API fields.
        let license = LicenseType.unknown
        let stream = StreamSource(
            providerID: self.id,
            streamURL: streamURL,
            format: .mp3,
            bitrate: nil,
            availability: .available,
            license: license,
            licenseURL: nil,
            attribution: attribution
        )

        return Track(
            id: "\(self.id)_\(id)",
            title: title,
            artist: artist,
            album: data.playlistName?.nilIfEmpty,
            artworkURL: artwork,
            duration: duration,
            providerID: self.id,
            sourceID: id,
            isrc: data.isrc?.nilIfEmpty,
            explicit: false,
            availableStreams: [stream],
            language: language,
            originalTitle: title,
            transliteratedTitle: LanguageDetector.isCyrillic(title) ? RussianText.transliterate(title) : nil,
            license: license,
            licenseURL: nil,
            attribution: attribution,
            isStreamAllowed: true,
            isDownloadAllowed: data.downloadable == true,
            downloadURL: nil,
            sourcePageURL: sourcePage,
            region: nil,
            genre: data.genre?.nilIfEmpty,
            releaseDate: releaseDate,
            trackNumber: nil,
            albumID: nil
        )
    }

    private func mapUser(_ user: AudiusUser) -> Artist {
        let name = clean(user.name ?? user.handle ?? "Неизвестный исполнитель")
        let artwork = user.profilePicture?.bestURL ?? user.profilePictureSizes.flatMap { URL(string: $0) }
        return Artist(
            id: user.id,
            name: name,
            artworkURL: artwork,
            biography: user.bio?.nilIfEmpty,
            providerID: id
        )
    }

    private func mapPlaylist(_ playlist: AudiusPlaylist) -> Album? {
        let title = clean(playlist.playlistName ?? "")
        guard !title.isEmpty else { return nil }
        let artist = clean(playlist.user?.name ?? playlist.user?.handle ?? "Неизвестный исполнитель")
        return Album(
            id: "\(id)_playlist_\(playlist.id)",
            title: title,
            artist: artist,
            artworkURL: playlist.artwork?.bestURL,
            releaseDate: parseTimestamp(playlist.releaseDateMs) ?? parseDate(playlist.releaseDate),
            providerID: id,
            tracks: []
        )
    }

    private func bestArtwork(for track: AudiusTrack) -> URL? {
        track.artwork?.bestURL
            ?? track.artworkSizes.flatMap { URL(string: $0) }
            ?? track.user?.profilePicture?.bestURL
    }

    private func parseDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: value) { return date }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: value) { return date }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    private func parseTimestamp(_ ms: Int64?) -> Date? {
        guard let ms, ms > 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(ms) / 1000.0)
    }

    private func clean(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Models

private struct AudiusBootstrapResponse: Decodable { let data: [String]? }

private struct AudiusTracksResponse: Decodable { let data: [AudiusTrack] }
private struct AudiusTrackResponse: Decodable { let data: AudiusTrack? }
private struct AudiusUsersResponse: Decodable { let data: [AudiusUser] }
private struct AudiusUserResponse: Decodable { let data: AudiusUser? }
private struct AudiusPlaylistsResponse: Decodable { let data: [AudiusPlaylist] }

private struct AudiusTrack: Decodable {
    let id: String
    let title: String?
    let duration: Int?
    let genre: String?
    let mood: String?
    let releaseDate: String?
    let releaseDateMs: Int64?
    let permalink: String?
    let isStreamable: Bool?
    let isrc: String?
    let downloadable: Bool?
    let streamConditions: AudiusAnyCodable?
    let artwork: AudiusArtwork?
    let artworkSizes: String?
    let user: AudiusUser?
    let playlistName: String?

    enum CodingKeys: String, CodingKey {
        case id, title, duration, genre, mood, permalink, isrc, downloadable, artwork, user
        case releaseDate = "release_date"
        case releaseDateMs = "release_date_ms"
        case isStreamable = "is_streamable"
        case streamConditions = "stream_conditions"
        case artworkSizes = "artwork"
        case playlistName = "playlist_name"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id))
            ?? (try? c.decode(Int.self, forKey: .id)).map(String.init)
            ?? ""
        title = try? c.decodeIfPresent(String.self, forKey: .title)
        duration = try? c.decodeIfPresent(Int.self, forKey: .duration)
        genre = try? c.decodeIfPresent(String.self, forKey: .genre)
        mood = try? c.decodeIfPresent(String.self, forKey: .mood)
        releaseDate = try? c.decodeIfPresent(String.self, forKey: .releaseDate)
        releaseDateMs = (try? c.decodeIfPresent(Int64.self, forKey: .releaseDateMs))
            ?? (try? c.decodeIfPresent(Int.self, forKey: .releaseDateMs)).map(Int64.init)
        permalink = try? c.decodeIfPresent(String.self, forKey: .permalink)
        isStreamable = try? c.decodeIfPresent(Bool.self, forKey: .isStreamable)
        isrc = try? c.decodeIfPresent(String.self, forKey: .isrc)
        downloadable = try? c.decodeIfPresent(Bool.self, forKey: .downloadable)
        streamConditions = try? c.decodeIfPresent(AudiusAnyCodable.self, forKey: .streamConditions)
        artwork = try? c.decodeIfPresent(AudiusArtwork.self, forKey: .artwork)
        artworkSizes = try? c.decodeIfPresent(String.self, forKey: .artworkSizes)
        user = try? c.decodeIfPresent(AudiusUser.self, forKey: .user)
        playlistName = try? c.decodeIfPresent(String.self, forKey: .playlistName)
    }
}

private struct AudiusUser: Decodable {
    let id: String
    let name: String?
    let handle: String?
    let bio: String?
    let profilePicture: AudiusArtwork?
    let profilePictureSizes: String?

    enum CodingKeys: String, CodingKey {
        case id, name, handle, bio
        case profilePicture = "profile_picture"
        case profilePictureSizes = "profile_picture_sizes"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id))
            ?? (try? c.decode(Int.self, forKey: .id)).map(String.init)
            ?? ""
        name = try? c.decodeIfPresent(String.self, forKey: .name)
        handle = try? c.decodeIfPresent(String.self, forKey: .handle)
        bio = try? c.decodeIfPresent(String.self, forKey: .bio)
        profilePicture = try? c.decodeIfPresent(AudiusArtwork.self, forKey: .profilePicture)
        profilePictureSizes = try? c.decodeIfPresent(String.self, forKey: .profilePictureSizes)
    }
}

private struct AudiusPlaylist: Decodable {
    let id: String
    let playlistName: String?
    let artwork: AudiusArtwork?
    let user: AudiusUser?
    let releaseDate: String?
    let releaseDateMs: Int64?

    enum CodingKeys: String, CodingKey {
        case id, artwork, user
        case playlistName = "playlist_name"
        case releaseDate = "release_date"
        case releaseDateMs = "release_date_ms"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id))
            ?? (try? c.decode(Int.self, forKey: .id)).map(String.init)
            ?? ""
        playlistName = try? c.decodeIfPresent(String.self, forKey: .playlistName)
        artwork = try? c.decodeIfPresent(AudiusArtwork.self, forKey: .artwork)
        user = try? c.decodeIfPresent(AudiusUser.self, forKey: .user)
        releaseDate = try? c.decodeIfPresent(String.self, forKey: .releaseDate)
        releaseDateMs = (try? c.decodeIfPresent(Int64.self, forKey: .releaseDateMs))
            ?? (try? c.decodeIfPresent(Int.self, forKey: .releaseDateMs)).map(Int64.init)
    }
}

private struct AudiusArtwork: Decodable {
    let x150: String?
    let x480: String?
    let x1000: String?

    enum CodingKeys: String, CodingKey {
        case x150 = "150x150"
        case x480 = "480x480"
        case x1000 = "1000x1000"
    }

    var bestURL: URL? {
        [x1000, x480, x150].compactMap { $0 }.compactMap(URL.init).first
    }
}

private struct AudiusAnyCodable: Decodable {}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
