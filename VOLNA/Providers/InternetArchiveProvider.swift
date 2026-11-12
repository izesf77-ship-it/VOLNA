import Foundation

/// Internet Archive Music Provider
/// API Documentation: https://archive.org/developers/
/// 13M+ audio recordings with various licenses
actor InternetArchiveProvider: MusicProvider {
    let id = "internet_archive"
    let name = "Internet Archive"
    
    let capabilities = ProviderCapabilities(
        supportsSearch: true,
        supportsStreaming: true,
        supportsArtwork: true,
        supportsAlbums: false,
        supportsArtists: false,
        supportsLyrics: false,
        supportsDownload: true,
        requiresAuthentication: false
    )
    
    private let baseURL = "https://archive.org"
    private let urlSession: URLSession
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.requestCachePolicy = .returnCacheDataElseLoad
        self.urlSession = URLSession(configuration: config)
    }
    
    // MARK: - MusicProvider Implementation
    
    func search(query: String, type: SearchType) async throws -> SearchResult {
        let tracks = try await searchAudio(query: query, limit: 20)
        
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
        
        // Stream URL should already be in availableStreams
        return track.availableStreams.first
    }
    
    func fetchArtist(id: String) async throws -> Artist? {
        throw ProviderError.notSupported
    }
    
    func fetchAlbum(id: String) async throws -> Album? {
        throw ProviderError.notSupported
    }
    
    // MARK: - Private Methods
    
    private func searchAudio(query: String, limit: Int = 20) async throws -> [Track] {
        // Build search query for audio items
        // Include Russian language filter if query contains Cyrillic
        let hasRussian = query.range(of: "\\p{Cyrillic}", options: .regularExpression) != nil
        
        var searchQuery = "(title:(\(query)) OR creator:(\(query))) AND mediatype:audio"
        
        // Add language filter for Russian queries
        if hasRussian {
            searchQuery += " AND (language:Russian OR language:ru)"
        }
        
        let url = buildSearchURL(query: searchQuery, limit: limit)
        
        let response: ArchiveSearchResponse = try await performRequest(url: url)
        
        // Fetch detailed metadata for each item
        var tracks: [Track] = []
        
        for item in response.response.docs.prefix(limit) {
            do {
                if let track = try await fetchTrackMetadata(identifier: item.identifier) {
                    tracks.append(track)
                }
            } catch {
                print("⚠️ Failed to fetch metadata for \(item.identifier): \(error)")
                continue
            }
        }
        
        return tracks
    }
    
    private func fetchTrackMetadata(identifier: String) async throws -> Track? {
        let url = URL(string: "\(baseURL)/metadata/\(identifier)")!
        
        let metadata: ArchiveMetadata = try await performRequest(url: url)
        
        // Find audio files
        guard let audioFile = metadata.files.first(where: { file in
            let format = file.format?.lowercased() ?? ""
            return format.contains("mp3") || 
                   format.contains("vorbis") ||
                   format.contains("flac") ||
                   format.contains("m4a")
        }) else {
            return nil
        }
        
        // Build stream URL
        let streamURL = URL(string: "\(baseURL)/download/\(identifier)/\(audioFile.name)")!
        
        // Parse license
        let license = parseLicense(from: metadata.metadata)
        
        // Detect language
        let language = metadata.metadata.language?.first ?? 
                      (metadata.metadata.subject?.contains("Russian") == true ? "ru" : nil)
        
        let streamSource = StreamSource(
            providerID: self.id,
            streamURL: streamURL,
            format: parseFormat(from: audioFile.format ?? ""),
            bitrate: nil,
            availability: .available
        )
        
        return Track(
            id: "\(self.id)_\(identifier)",
            title: metadata.metadata.title?.first ?? identifier,
            artist: metadata.metadata.creator?.first ?? "Unknown",
            album: nil,
            artworkURL: buildThumbnailURL(identifier: identifier),
            duration: TimeInterval(audioFile.length?.parseDouble() ?? 0),
            providerID: self.id,
            sourceID: identifier,
            isrc: nil,
            explicit: false,
            availableStreams: [streamSource],
            language: language,
            originalTitle: metadata.metadata.title?.first,
            transliteratedTitle: nil,
            license: license,
            licenseURL: URL(string: metadata.metadata.licenseurl ?? ""),
            attribution: buildAttribution(from: metadata.metadata),
            isStreamAllowed: true,
            isDownloadAllowed: checkDownloadAllowed(license: license),
            region: nil,
            genre: metadata.metadata.subject?.first
        )
    }
    
    private func buildSearchURL(query: String, limit: Int) -> URL {
        var components = URLComponents(string: "\(baseURL)/advancedsearch.php")!
        
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "fl", value: "identifier,title,creator,date,downloads,format"),
            URLQueryItem(name: "output", value: "json"),
            URLQueryItem(name: "rows", value: "\(limit)")
        ]
        
        return components.url!
    }
    
    private func buildThumbnailURL(identifier: String) -> URL? {
        // Internet Archive thumbnail pattern
        URL(string: "\(baseURL)/services/img/\(identifier)")
    }
    
    private func parseLicense(from metadata: ArchiveItemMetadata) -> LicenseType {
        let licenseText = metadata.licenseurl?.lowercased() ?? ""
        
        if licenseText.contains("creativecommons.org/publicdomain/zero") {
            return .cc0
        } else if licenseText.contains("creativecommons.org/licenses/by-sa") {
            return .ccBySa
        } else if licenseText.contains("creativecommons.org/licenses/by-nc-sa") {
            return .ccByNcSa
        } else if licenseText.contains("creativecommons.org/licenses/by-nc-nd") {
            return .ccByNcNd
        } else if licenseText.contains("creativecommons.org/licenses/by-nc") {
            return .ccByNc
        } else if licenseText.contains("creativecommons.org/licenses/by-nd") {
            return .ccByNd
        } else if licenseText.contains("creativecommons.org/licenses/by") {
            return .ccBy
        } else if licenseText.contains("publicdomain") ||
                  metadata.licenseurl?.contains("mark/1.0") == true {
            return .publicDomain
        } else if !licenseText.isEmpty {
            return .other
        } else {
            return .unknown
        }
    }
    
    private func parseFormat(from formatString: String) -> AudioFormat {
        let format = formatString.lowercased()
        
        if format.contains("mp3") {
            return .mp3
        } else if format.contains("vorbis") || format.contains("ogg") {
            return .ogg
        } else if format.contains("flac") {
            return .flac
        } else if format.contains("m4a") || format.contains("aac") {
            return .m4a
        } else {
            return .unknown
        }
    }
    
    private func buildAttribution(from metadata: ArchiveItemMetadata) -> String? {
        guard let creator = metadata.creator?.first else {
            return nil
        }
        
        let title = metadata.title?.first ?? "Untitled"
        return "\(title) by \(creator) (Internet Archive)"
    }
    
    private func checkDownloadAllowed(license: LicenseType) -> Bool {
        // Most Internet Archive content allows download
        switch license {
        case .restricted, .unknown:
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
                print("❌ Internet Archive decode error: \(error)")
                print("Response data: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
                throw ProviderError.invalidResponse
            }
        case 429:
            throw ProviderError.rateLimitExceeded
        case 404:
            throw ProviderError.resourceNotFound
        default:
            print("❌ Internet Archive HTTP error: \(httpResponse.statusCode)")
            throw ProviderError.invalidResponse
        }
    }
}

// MARK: - Internet Archive API Response Models

private struct ArchiveSearchResponse: Decodable {
    let response: ArchiveResponse
}

private struct ArchiveResponse: Decodable {
    let docs: [ArchiveSearchDoc]
}

private struct ArchiveSearchDoc: Decodable {
    let identifier: String
    let title: String?
    let creator: [String]?
}

private struct ArchiveMetadata: Decodable {
    let metadata: ArchiveItemMetadata
    let files: [ArchiveFile]
}

private struct ArchiveItemMetadata: Decodable {
    let title: [String]?
    let creator: [String]?
    let date: String?
    let description: [String]?
    let subject: [String]?
    let language: [String]?
    let licenseurl: String?
    
    enum CodingKeys: String, CodingKey {
        case title
        case creator
        case date
        case description
        case subject
        case language
        case licenseurl
    }
}

private struct ArchiveFile: Decodable {
    let name: String
    let format: String?
    let size: String?
    let length: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case format
        case size
        case length
    }
}

// MARK: - Helper Extensions

private extension String {
    func parseDouble() -> Double? {
        return Double(self)
    }
}
