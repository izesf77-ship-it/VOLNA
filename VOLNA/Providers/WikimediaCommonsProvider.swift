import Foundation

/// Wikimedia Commons Audio Provider
/// API Documentation: https://www.mediawiki.org/wiki/API:Main_page
/// Free-licensed audio files from Wikimedia Commons
actor WikimediaCommonsProvider: MusicProvider {
    let id = "wikimedia_commons"
    let name = "Wikimedia Commons"
    
    let capabilities = ProviderCapabilities(
        supportsSearch: true,
        supportsStreaming: true,
        supportsArtwork: false,
        supportsAlbums: false,
        supportsArtists: false,
        supportsLyrics: false,
        supportsDownload: true,
        requiresAuthentication: false
    )
    
    private let baseURL = "https://commons.wikimedia.org/w/api.php"
    private let urlSession: URLSession
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.requestCachePolicy = .returnCacheDataElseLoad
        self.urlSession = URLSession(configuration: config)
    }
    
    // MARK: - MusicProvider Implementation
    
    func search(query: String, type: SearchType) async throws -> SearchResult {
        let tracks = try await searchAudioFiles(query: query, limit: 20)
        
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
        
        return track.availableStreams.first
    }
    
    func fetchArtist(id: String) async throws -> Artist? {
        throw ProviderError.notSupported
    }
    
    func fetchAlbum(id: String) async throws -> Album? {
        throw ProviderError.notSupported
    }
    
    // MARK: - Private Methods
    
    private func searchAudioFiles(query: String, limit: Int = 20) async throws -> [Track] {
        // Search for audio files
        let searchQuery = "filetype:audio \(query)"
        let url = buildSearchURL(query: searchQuery, limit: limit)
        
        let searchResponse: WikiSearchResponse = try await performRequest(url: url)
        
        guard let pages = searchResponse.query?.search else {
            return []
        }
        
        var tracks: [Track] = []
        
        // Fetch file info for each result
        for page in pages.prefix(limit) {
            let filename = page.title
            
            do {
                if let track = try await fetchFileInfo(filename: filename) {
                    tracks.append(track)
                }
            } catch {
                print("⚠️ Failed to fetch file info for \(filename): \(error)")
                continue
            }
        }
        
        return tracks
    }
    
    private func fetchFileInfo(filename: String) async throws -> Track? {
        let url = buildFileInfoURL(filename: filename)
        
        let response: WikiFileInfoResponse = try await performRequest(url: url)
        
        guard let pages = response.query?.pages,
              let page = pages.values.first,
              let imageInfo = page.imageinfo?.first else {
            return nil
        }
        
        // Only process audio files
        guard let mime = imageInfo.mime,
              mime.starts(with: "audio/") else {
            return nil
        }
        
        // Parse metadata
        let extMetadata = imageInfo.extmetadata
        
        // Extract title (remove "File:" prefix)
        let title = extractTitle(from: filename, metadata: extMetadata)
        let artist = extMetadata?.artist?.value ?? "Unknown"
        
        // Parse license
        let license = parseLicense(from: extMetadata)
        
        // Detect language (check categories or description)
        let language = detectLanguage(from: extMetadata, filename: filename)
        
        let streamSource = StreamSource(
            providerID: self.id,
            streamURL: imageInfo.url,
            format: parseFormat(from: mime),
            bitrate: nil,
            availability: .available
        )
        
        return Track(
            id: "\(self.id)_\(page.pageid)",
            title: title,
            artist: artist,
            album: nil,
            artworkURL: imageInfo.thumburl,
            duration: TimeInterval(imageInfo.duration ?? 0),
            providerID: self.id,
            sourceID: "\(page.pageid)",
            isrc: nil,
            explicit: false,
            availableStreams: [streamSource],
            language: language,
            originalTitle: title,
            transliteratedTitle: nil,
            license: license,
            licenseURL: parseLicenseURL(from: extMetadata),
            attribution: extMetadata?.attribution?.value,
            isStreamAllowed: true,
            isDownloadAllowed: checkDownloadAllowed(license: license),
            region: nil,
            genre: extractGenre(from: extMetadata)
        )
    }
    
    private func buildSearchURL(query: String, limit: Int) -> URL {
        var components = URLComponents(string: baseURL)!
        
        components.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "list", value: "search"),
            URLQueryItem(name: "srsearch", value: query),
            URLQueryItem(name: "srnamespace", value: "6"), // File namespace
            URLQueryItem(name: "srlimit", value: "\(limit)"),
            URLQueryItem(name: "format", value: "json")
        ]
        
        return components.url!
    }
    
    private func buildFileInfoURL(filename: String) -> URL {
        var components = URLComponents(string: baseURL)!
        
        components.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "prop", value: "imageinfo"),
            URLQueryItem(name: "iiprop", value: "url|size|mime|extmetadata|duration"),
            URLQueryItem(name: "titles", value: filename),
            URLQueryItem(name: "format", value: "json")
        ]
        
        return components.url!
    }
    
    private func extractTitle(from filename: String, metadata: WikiExtMetadata?) -> String {
        // Try to get title from metadata
        if let objectName = metadata?.objectName?.value {
            return objectName
        }
        
        // Remove "File:" prefix and extension
        var title = filename.replacingOccurrences(of: "File:", with: "")
        if let lastDot = title.lastIndex(of: ".") {
            title = String(title[..<lastDot])
        }
        
        // Replace underscores with spaces
        title = title.replacingOccurrences(of: "_", with: " ")
        
        return title
    }
    
    private func parseLicense(from metadata: WikiExtMetadata?) -> LicenseType {
        guard let licenseShortName = metadata?.licenseShortName?.value?.lowercased() else {
            return .unknown
        }
        
        if licenseShortName.contains("cc0") || licenseShortName.contains("cc 0") {
            return .cc0
        } else if licenseShortName.contains("cc-by-sa") || licenseShortName.contains("cc by-sa") {
            return .ccBySa
        } else if licenseShortName.contains("cc-by-nc-sa") {
            return .ccByNcSa
        } else if licenseShortName.contains("cc-by-nc-nd") {
            return .ccByNcNd
        } else if licenseShortName.contains("cc-by-nc") {
            return .ccByNc
        } else if licenseShortName.contains("cc-by-nd") {
            return .ccByNd
        } else if licenseShortName.contains("cc-by") || licenseShortName.contains("cc by") {
            return .ccBy
        } else if licenseShortName.contains("public domain") || licenseShortName.contains("pd") {
            return .publicDomain
        } else {
            return .other
        }
    }
    
    private func parseLicenseURL(from metadata: WikiExtMetadata?) -> URL? {
        guard let urlString = metadata?.licenseUrl?.value else {
            return nil
        }
        return URL(string: urlString)
    }
    
    private func detectLanguage(from metadata: WikiExtMetadata?, filename: String) -> String? {
        // Check if Russian is mentioned in categories or description
        let filenameLC = filename.lowercased()
        
        if filenameLC.contains("russian") || 
           filenameLC.contains("русск") ||
           filenameLC.range(of: "\\p{Cyrillic}", options: .regularExpression) != nil {
            return "ru"
        }
        
        // Check categories in metadata
        if let categories = metadata?.categories?.value {
            if categories.lowercased().contains("russian") {
                return "ru"
            }
        }
        
        return nil
    }
    
    private func extractGenre(from metadata: WikiExtMetadata?) -> String? {
        // Try to extract genre from categories
        if let categories = metadata?.categories?.value {
            let catLC = categories.lowercased()
            
            if catLC.contains("folk") {
                return "Folk"
            } else if catLC.contains("classical") {
                return "Classical"
            } else if catLC.contains("rock") {
                return "Rock"
            } else if catLC.contains("jazz") {
                return "Jazz"
            }
        }
        
        return nil
    }
    
    private func parseFormat(from mime: String) -> AudioFormat {
        if mime.contains("mpeg") || mime.contains("mp3") {
            return .mp3
        } else if mime.contains("ogg") {
            return .ogg
        } else if mime.contains("flac") {
            return .flac
        } else if mime.contains("wav") {
            return .wav
        } else if mime.contains("m4a") || mime.contains("aac") {
            return .m4a
        } else {
            return .unknown
        }
    }
    
    private func checkDownloadAllowed(license: LicenseType) -> Bool {
        // Wikimedia Commons content is generally downloadable
        switch license {
        case .restricted:
            return false
        default:
            return true
        }
    }
    
    private func performRequest<T: Decodable>(url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue("VOLNA/0.2.0 (https://github.com/volna/ios)", forHTTPHeaderField: "User-Agent")
        
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
                print("❌ Wikimedia Commons decode error: \(error)")
                print("Response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
                throw ProviderError.invalidResponse
            }
        case 429:
            throw ProviderError.rateLimitExceeded
        case 404:
            throw ProviderError.resourceNotFound
        default:
            print("❌ Wikimedia Commons HTTP error: \(httpResponse.statusCode)")
            throw ProviderError.invalidResponse
        }
    }
}

// MARK: - Wikimedia API Response Models

private struct WikiSearchResponse: Decodable {
    let query: WikiQuery?
}

private struct WikiQuery: Decodable {
    let search: [WikiSearchResult]?
    let pages: [String: WikiPage]?
}

private struct WikiSearchResult: Decodable {
    let title: String
    let pageid: Int
}

private struct WikiFileInfoResponse: Decodable {
    let query: WikiFileQuery?
}

private struct WikiFileQuery: Decodable {
    let pages: [String: WikiPage]?
}

private struct WikiPage: Decodable {
    let pageid: Int
    let title: String
    let imageinfo: [WikiImageInfo]?
}

private struct WikiImageInfo: Decodable {
    let url: URL
    let thumburl: URL?
    let mime: String?
    let size: Int?
    let duration: Double?
    let extmetadata: WikiExtMetadata?
}

private struct WikiExtMetadata: Decodable {
    let objectName: WikiMetadataValue?
    let artist: WikiMetadataValue?
    let licenseShortName: WikiMetadataValue?
    let licenseUrl: WikiMetadataValue?
    let attribution: WikiMetadataValue?
    let categories: WikiMetadataValue?
    
    enum CodingKeys: String, CodingKey {
        case objectName = "ObjectName"
        case artist = "Artist"
        case licenseShortName = "LicenseShortName"
        case licenseUrl = "LicenseUrl"
        case attribution = "Attribution"
        case categories = "Categories"
    }
}

private struct WikiMetadataValue: Decodable {
    let value: String
}
