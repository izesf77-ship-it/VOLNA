import Foundation

/// Internet Archive Provider.
/// Документация: https://archive.org/developers/
///
/// В поиск попадают только элементы, у которых явно указан `licenseurl`
/// (Creative Commons или public domain). Элементы без лицензии не выдаются за
/// свободные. Для каждого элемента выбираются MP3/M4A-файлы, которые способен
/// воспроизвести AVPlayer.
actor InternetArchiveProvider: MusicProvider {
    nonisolated let id = "internet_archive"
    nonisolated let name = "Internet Archive"

    nonisolated let capabilities = ProviderCapabilities(
        supportsSearch: true,
        supportsStreaming: true,
        supportsArtwork: true,
        supportsAlbums: false,
        supportsArtists: false,
        supportsLyrics: false,
        supportsDownload: true,
        requiresAuthentication: false,
        supportsRussian: true,
        isLocal: false
    )

    private let baseURL = "https://archive.org"
    private let urlSession: URLSession

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 25
        configuration.timeoutIntervalForResource = 45
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.httpAdditionalHeaders = ["Accept": "application/json"]
        self.urlSession = URLSession(configuration: configuration)
    }

    // MARK: - MusicProvider

    func search(query: String, type: SearchType) async throws -> SearchResult {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return SearchResult(providerID: id) }

        var tracks = try await searchItems(query: trimmed)
        if tracks.isEmpty, let variant = RussianText.queryVariants(trimmed).dropFirst().first {
            tracks = (try? await searchItems(query: variant)) ?? []
        }

        return SearchResult(tracks: Array(tracks.prefix(40)), providerID: id)
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
            let url = try buildSearchURL(
                query: "music AND mediatype:(audio) AND licenseurl:*",
                rows: 1
            )
            let response: ArchiveSearchResponse = try await performRequest(url)
            let latency = start.duration(to: .now).timeInterval
            return ProviderHealth(
                isAvailable: !(response.response?.docs.isEmpty ?? true),
                latency: latency,
                message: "Search API отвечает",
                sampleTrackCount: response.response?.docs.count
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

    private func searchItems(query: String) async throws -> [Track] {
        let escaped = sanitize(query)
        let lucene = """
        (title:(\(escaped)) OR creator:(\(escaped)) OR subject:(\(escaped)))
        AND mediatype:(audio) AND licenseurl:*
        """
        let url = try buildSearchURL(query: lucene, rows: 12)
        let response: ArchiveSearchResponse = try await performRequest(url)
        guard let body = response.response else {
            throw ProviderError.invalidResponse("в ответе Archive нет поля response")
        }

        let docs = Array(body.docs.prefix(12))
        guard !docs.isEmpty else { return [] }

        let perItemTracks = await withTaskGroup(
            of: (Int, [Track]).self,
            returning: [(Int, [Track])].self
        ) { group in
            for (index, doc) in docs.enumerated() {
                group.addTask {
                    do {
                        let tracks = try await self.tracks(for: doc, maxTracks: 8)
                        return (index, tracks)
                    } catch {
                        return (index, [])
                    }
                }
            }
            var collected: [(Int, [Track])] = []
            for await item in group {
                collected.append(item)
            }
            return collected.sorted { $0.0 < $1.0 }
        }

        return perItemTracks.flatMap { $0.1 }
    }

    private func tracks(for doc: ArchiveSearchDoc, maxTracks: Int) async throws -> [Track] {
        let metadataURL = URL(string: "\(baseURL)/metadata/\(doc.identifier)")!
        let response: ArchiveMetadataResponse = try await performRequest(metadataURL)
        guard let item = response.metadata else { return [] }

        if item.isAccessRestricted {
            return []
        }

        let license = LicenseParser.parse(urlString: item.licenseurl?.value)
        guard license.isKnownOpenLicense else {
            return []
        }

        let audioFiles = (response.files ?? []).compactMap { file -> ArchivePlayableFile? in
            guard let name = file.name?.value, !name.isEmpty,
                  let format = file.format?.value else {
                return nil
            }
            let lower = format.lowercased()
            guard lower.contains("mp3") || lower.contains("m4a") ||
                    lower.contains("aac") || lower.contains("mp4") else {
                return nil
            }
            if name.lowercased().hasSuffix(".zip") { return nil }
            return ArchivePlayableFile(file: file, name: name, format: lower)
        }

        let selected = selectBestFiles(audioFiles, maxTracks: maxTracks)
        guard !selected.isEmpty else { return [] }

        let itemTitle = item.title?.values.first?.trimmingCharacters(in: .whitespacesAndNewlines)
        let creator = item.creator?.values.first
        let album = selected.count > 1 ? itemTitle : nil
        let artwork = URL(string: "\(baseURL)/services/img/\(doc.identifier)")
        let page = URL(string: "\(baseURL)/details/\(doc.identifier)")
        let licenseURL = URL(string: item.licenseurl?.value ?? "")
            ?? LicenseParser.defaultURL(for: license)
        let genre = item.subject?.values.first(where: {
            let value = $0.lowercased()
            return !value.isEmpty && value != "russian" && value != "русский"
        })

        return selected.compactMap { audio in
            let file = audio.file
            let title = nonEmpty(file.title?.value)
                ?? (selected.count == 1 ? itemTitle : nil)
                ?? cleanFileName(audio.name)
            guard !title.isEmpty else { return nil }

            let artist = nonEmpty(file.artist?.value)
                ?? creator
                ?? "Неизвестный исполнитель"
            let trackAlbum = nonEmpty(file.album?.value) ?? album
            let language = LanguageDetector.detect(
                declared: item.language?.values.first,
                texts: [title, artist, trackAlbum]
            )
            guard let streamURL = archiveDownloadURL(
                identifier: doc.identifier,
                fileName: audio.name
            ) else {
                return nil
            }

            let duration = file.length?.value.flatMap { Double($0) }
            let attribution = [
                "«\(title)» — \(artist)",
                "источник: Internet Archive",
                "лицензия: \(license.displayName)",
                "страница: \(baseURL)/details/\(doc.identifier)"
            ].joined(separator: ", ")

            let stream = StreamSource(
                providerID: id,
                streamURL: streamURL,
                format: ArchivePlayableFile.format(for: audio.format),
                bitrate: nil,
                availability: .available,
                license: license,
                licenseURL: licenseURL,
                attribution: attribution
            )

            return Track(
                id: "\(id)_\(doc.identifier)_\(audio.name.stableFNVHash)",
                title: title,
                artist: artist,
                album: trackAlbum,
                artworkURL: artwork,
                duration: duration,
                providerID: id,
                sourceID: "\(doc.identifier)/\(audio.name)",
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
                isDownloadAllowed: true,
                downloadURL: streamURL,
                sourcePageURL: page,
                region: nil,
                genre: genre
            )
        }
    }

    // MARK: - File selection

    private func selectBestFiles(
        _ files: [ArchivePlayableFile],
        maxTracks: Int
    ) -> [ArchivePlayableFile] {
        var bestByBase: [String: ArchivePlayableFile] = [:]
        for file in files {
            let base = baseAudioName(file.name)
            if let existing = bestByBase[base] {
                if file.qualityScore < existing.qualityScore {
                    bestByBase[base] = file
                }
            } else {
                bestByBase[base] = file
            }
        }
        return bestByBase.values
            .sorted {
                if $0.qualityScore != $1.qualityScore {
                    return $0.qualityScore < $1.qualityScore
                }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            .prefix(maxTracks)
            .map { $0 }
    }

    private func baseAudioName(_ name: String) -> String {
        var value = (name as NSString).deletingPathExtension
        let patterns = [
            #"_64kb$"#, #"_128kb$"#, #"_64kbps$"#, #"_128kbps$"#,
            #"_vbr$"#, #"\.mp3$"#, #"\s*\(\d+\)$"#
        ]
        for pattern in patterns {
            value = value.replacingOccurrences(
                of: pattern,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        return value.lowercased()
    }

    private func cleanFileName(_ name: String) -> String {
        var value = (name as NSString).deletingPathExtension
        value = value.replacingOccurrences(of: "_", with: " ")
        value = value.replacingOccurrences(
            of: #"^\s*\d{1,3}\s*[-\.\)]?\s*"#,
            with: "",
            options: .regularExpression
        )
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Networking

    private func buildSearchURL(query: String, rows: Int) throws -> URL {
        var components = URLComponents(string: "\(baseURL)/advancedsearch.php")
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "fl[]", value: "identifier"),
            URLQueryItem(name: "fl[]", value: "title"),
            URLQueryItem(name: "fl[]", value: "creator"),
            URLQueryItem(name: "fl[]", value: "year"),
            URLQueryItem(name: "fl[]", value: "licenseurl"),
            URLQueryItem(name: "fl[]", value: "downloads"),
            URLQueryItem(name: "rows", value: "\(rows)"),
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "output", value: "json"),
            URLQueryItem(name: "sort[]", value: "downloads desc")
        ]
        guard let url = components?.url else {
            throw ProviderError.invalidConfiguration
        }
        return url
    }

    private func performRequest<T: Decodable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue("VOLNA/1.0 (iOS; open music player; contact: github.com/izesf77-ship-it/VOLNA)", forHTTPHeaderField: "User-Agent")
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
                throw ProviderError.invalidResponse("не удалось разобрать JSON Internet Archive")
            }
        case 429:
            throw ProviderError.rateLimitExceeded
        case 404:
            throw ProviderError.resourceNotFound
        default:
            throw ProviderError.invalidResponse("HTTP \(http.statusCode)")
        }
    }

    private func archiveDownloadURL(identifier: String, fileName: String) -> URL? {
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "#?"))
        guard let encodedName = fileName.addingPercentEncoding(withAllowedCharacters: allowed),
              let encodedID = identifier.addingPercentEncoding(withAllowedCharacters: allowed) else {
            return nil
        }
        return URL(string: "\(baseURL)/download/\(encodedID)/\(encodedName)")
    }

    private func sanitize(_ query: String) -> String {
        let forbidden = CharacterSet(charactersIn: "\"()[]{}:^~\\")
        let cleaned = query.unicodeScalars.map { scalar -> Character in
            forbidden.contains(scalar) ? " " : Character(scalar)
        }
        let result = String(cleaned)
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        return result.isEmpty ? "music" : result
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - Helpers

private struct ArchivePlayableFile {
    let file: ArchiveFile
    let name: String
    let format: String

    var qualityScore: Int {
        switch format {
        case "mp3": return 0
        case "vbr mp3": return 1
        case "192kbps mp3": return 2
        case "128kbps mp3": return 3
        case "64kbps mp3": return 4
        case "m4a", "aac", "mp4": return 5
        default: return 9
        }
    }

    static func format(for raw: String) -> AudioFormat {
        if raw.contains("m4a") || raw.contains("mp4") { return .m4a }
        if raw.contains("aac") { return .aac }
        return .mp3
    }
}

// MARK: - Flexible JSON values

private struct FlexibleString: Decodable {
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
        if let bool = try? container.decode(Bool.self) {
            value = String(bool)
            return
        }
        if let array = try? container.decode([String].self),
           let first = array.first {
            value = first
            return
        }
        if let array = try? container.decode([FlexibleString].self),
           let first = array.first?.value {
            value = first
            return
        }
        value = nil
    }
}

private struct FlexibleStringArray: Decodable {
    let values: [String]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let values = try? container.decode([FlexibleString].self) {
            self.values = values.compactMap(\.value)
            return
        }
        if let single = try? container.decode(FlexibleString.self) {
            self.values = single.value.map { [$0] } ?? []
            return
        }
        self.values = []
    }
}

// MARK: - API models

private struct ArchiveSearchResponse: Decodable {
    let response: ArchiveSearchResponseBody?
}

private struct ArchiveSearchResponseBody: Decodable {
    let docs: [ArchiveSearchDoc]
    let numFound: Int?

    enum CodingKeys: String, CodingKey {
        case docs
        case numFound = "numFound"
    }
}

private struct ArchiveSearchDoc: Decodable {
    let identifier: String
    let title: FlexibleString?
    let creator: FlexibleStringArray?
    let year: FlexibleString?
    let licenseurl: FlexibleString?
    let downloads: Int?
}

private struct ArchiveMetadataResponse: Decodable {
    let metadata: ArchiveItemMetadata?
    let files: [ArchiveFile]?
}

private struct ArchiveItemMetadata: Decodable {
    let title: FlexibleStringArray?
    let creator: FlexibleStringArray?
    let date: FlexibleString?
    let description: FlexibleStringArray?
    let subject: FlexibleStringArray?
    let language: FlexibleStringArray?
    let licenseurl: FlexibleString?
    let collection: FlexibleStringArray?
    let accessRestrictedItem: FlexibleString?

    var isAccessRestricted: Bool {
        let raw = accessRestrictedItem?.value?.lowercased() ?? ""
        return raw == "true" || raw == "1" || raw == "yes"
    }

    enum CodingKeys: String, CodingKey {
        case title
        case creator
        case date
        case description
        case subject
        case language
        case licenseurl
        case collection
        case accessRestrictedItem = "access-restricted-item"
    }
}

private struct ArchiveFile: Decodable {
    let name: FlexibleString?
    let format: FlexibleString?
    let title: FlexibleString?
    let artist: FlexibleString?
    let album: FlexibleString?
    let track: FlexibleString?
    let length: FlexibleString?
    let original: FlexibleString?
}
