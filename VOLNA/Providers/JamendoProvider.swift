import Foundation

/// Jamendo Music Provider
/// API Documentation: https://developer.jamendo.com/v3.0/docs
/// 500,000+ Creative Commons licensed tracks
actor JamendoProvider: MusicProvider {
    let id = "jamendo"
    let name = "Jamendo"
    
    let capabilities = ProviderCapabilities(
        supportsSearch: true,
        supportsStreaming: true,
        supportsArtwork: true,
        supportsAlbums: true,
        supportsArtists: true,
        supportsLyrics: false,
        supportsDownload: true,
        requiresAuthentication: false
    )
    
    private let baseURL = "https://api.jamendo.com/v3.0"
    private let clientID = "YOUR_CLIENT_ID" // TODO: Get from config or environment
    
    private let urlSession: URLSession
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.urlSession = URLSession(configuration: config)
    }
    
    // MARK: - MusicProvider Implementation
    
    func search(query: String, type: SearchType) async throws -> SearchResult {
        // For now, search only tracks
        // TODO: Add album and artist search
        let tracks = try await searchTracks(query: query, limit: 20)
        
        return SearchResult(
            tracks: tracks,
            albums: [],
            artists: [],
            providerID: id
        )
    }
    
    func resolveStream(for track: Track) async throws -> StreamSource? {
        guard track.providerID == id else {
            throw ProviderError.invalidConfiguration
        }
        
        // Jamendo provides direct audio URLs
        // The stream URL should be included in availableStreams
        guard let existingStream = track.availableStreams.first else {
            return nil
        }
        
        return existingStream
    }
    
    func fetchArtist(id: String) async throws -> Artist? {
        let url = buildURL(
            endpoint: "/artists",
            parameters: [
                "id": id,
                "imagesize": "600"
            ]
        )
        
        let response: JamendoArtistsResponse = try await performRequest(url: url)
        guard let artistData = response.results.first else {
            throw ProviderError.resourceNotFound
        }
        
        return Artist(
            id: artistData.id,
            name: artistData.name,
            artworkURL: URL(string: artistData.image ?? ""),
            biography: artistData.shorturl,
            providerID: self.id
        )
    }
    
    func fetchAlbum(id: String) async throws -> Album? {
        let url = buildURL(
            endpoint: "/albums/tracks",
            parameters: [
                "id": id,
                "imagesize": "600",
                "audioformat": "mp32"
            ]
        )
        
        let response: JamendoAlbumTracksResponse = try await performRequest(url: url)
        guard let albumData = response.results.first else {
            throw ProviderError.resourceNotFound
        }
        
        let tracks = albumData.tracks.map { trackData in
            mapTrack(from: trackData, albumName: albumData.name, artworkURL: albumData.image)
        }
        
        return Album(
            id: albumData.id,
            title: albumData.name,
            artist: albumData.artistName ?? "Unknown",
            artworkURL: URL(string: albumData.image ?? ""),
            releaseDate: parseReleaseDate(albumData.releasedate),
            providerID: self.id,
            tracks: tracks
        )
    }
    
    // MARK: - Private Methods
    
    private func searchTracks(query: String, limit: Int = 20) async throws -> [Track] {
        let url = buildURL(
            endpoint: "/tracks",
            parameters: [
                "search": query,
                "limit": "\(limit)",
                "imagesize": "600",
                "audioformat": "mp32",
                "include": "musicinfo"
            ]
        )
        
        let response: JamendoTracksResponse = try await performRequest(url: url)
        
        return response.results.map { trackData in
            mapTrack(from: trackData)
        }
    }
    
    private func mapTrack(
        from data: JamendoTrack,
        albumName: String? = nil,
        artworkURL: String? = nil
    ) -> Track {
        let audioURL = URL(string: data.audio ?? "")
        let artwork = URL(string: artworkURL ?? data.image ?? data.albumImage ?? "")
        
        let streamSource = audioURL.map { url in
            StreamSource(
                providerID: self.id,
                streamURL: url,
                format: .mp3,
                bitrate: 320,
                availability: .available
            )
        }
        
        return Track(
            id: "\(self.id)_\(data.id)",
            title: data.name,
            artist: data.artistName ?? "Unknown",
            album: albumName ?? data.albumName,
            artworkURL: artwork,
            duration: TimeInterval(data.duration ?? 0),
            providerID: self.id,
            sourceID: data.id,
            isrc: nil,
            explicit: false,
            availableStreams: streamSource.map { [$0] } ?? []
        )
    }
    
    private func buildURL(endpoint: String, parameters: [String: String]) -> URL {
        var components = URLComponents(string: baseURL + endpoint)!
        
        var queryItems = [URLQueryItem(name: "client_id", value: clientID)]
        queryItems += parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        components.queryItems = queryItems
        
        return components.url!
    }
    
    private func performRequest<T: Decodable>(url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue("VOLNA/0.1.0", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProviderError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                print("❌ Jamendo decode error: \(error)")
                throw ProviderError.invalidResponse
            }
        case 429:
            throw ProviderError.rateLimitExceeded
        case 404:
            throw ProviderError.resourceNotFound
        default:
            throw ProviderError.invalidResponse
        }
    }
    
    private func parseReleaseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }
}

// MARK: - Jamendo API Response Models

private struct JamendoTracksResponse: Decodable {
    let results: [JamendoTrack]
}

private struct JamendoTrack: Decodable {
    let id: String
    let name: String
    let duration: Int?
    let artistName: String?
    let albumName: String?
    let albumImage: String?
    let image: String?
    let audio: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case duration
        case artistName = "artist_name"
        case albumName = "album_name"
        case albumImage = "album_image"
        case image
        case audio
    }
}

private struct JamendoArtistsResponse: Decodable {
    let results: [JamendoArtist]
}

private struct JamendoArtist: Decodable {
    let id: String
    let name: String
    let image: String?
    let shorturl: String?
}

private struct JamendoAlbumTracksResponse: Decodable {
    let results: [JamendoAlbumWithTracks]
}

private struct JamendoAlbumWithTracks: Decodable {
    let id: String
    let name: String
    let artistName: String?
    let image: String?
    let releasedate: String?
    let tracks: [JamendoTrack]
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case artistName = "artist_name"
        case image
        case releasedate
        case tracks
    }
}
