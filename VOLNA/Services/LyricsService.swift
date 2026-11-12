import Foundation

/// Сервис получения текстов песен из LRCLIB.
/// Документация: https://lrclib.net/docs
///
/// Сначала выполняется точный запрос `/api/get`, затем запасной `/api/search`.
/// Это важно для записей из открытых каталогов: длительность в метаданных
/// часто отличается на несколько секунд, и точный запрос может вернуть 404.
actor LyricsService {
    private let baseURL = "https://lrclib.net/api"
    private let urlSession: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 12
        config.timeoutIntervalForResource = 20
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.httpAdditionalHeaders = ["Accept": "application/json"]
        self.urlSession = URLSession(configuration: config)
    }

    /// Поиск текста по информации о композиции.
    func searchLyrics(
        trackName: String,
        artistName: String,
        albumName: String? = nil,
        duration: TimeInterval? = nil
    ) async throws -> Lyrics? {
        let cleanTitle = trackName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanArtist = artistName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return nil }

        if let exact = try await fetchExact(
            trackName: cleanTitle,
            artistName: cleanArtist,
            albumName: albumName,
            duration: duration
        ) {
            return exact
        }

        return try await searchFallback(
            trackName: cleanTitle,
            artistName: cleanArtist,
            duration: duration
        )
    }

    /// Получить текст по ID LRCLIB.
    func getLyrics(id: Int) async throws -> Lyrics {
        let url = URL(string: "\(baseURL)/get/\(id)")!
        guard let lyrics = try await fetchLyrics(from: url) else {
            throw LyricsError.notFound
        }
        return lyrics
    }

    // MARK: - Exact

    private func fetchExact(
        trackName: String,
        artistName: String,
        albumName: String?,
        duration: TimeInterval?
    ) async throws -> Lyrics? {
        var components = URLComponents(string: "\(baseURL)/get")!
        var queryItems = [
            URLQueryItem(name: "track_name", value: trackName),
            URLQueryItem(name: "artist_name", value: artistName)
        ]
        if let albumName, !albumName.isEmpty {
            queryItems.append(URLQueryItem(name: "album_name", value: albumName))
        }
        if let duration, duration > 0 {
            queryItems.append(URLQueryItem(name: "duration", value: "\(Int(duration.rounded()))"))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw LyricsError.invalidURL
        }
        return try await fetchLyrics(from: url)
    }

    // MARK: - Search fallback

    private func searchFallback(
        trackName: String,
        artistName: String,
        duration: TimeInterval?
    ) async throws -> Lyrics? {
        var components = URLComponents(string: "\(baseURL)/search")!
        var queryItems = [URLQueryItem(name: "track_name", value: trackName)]
        if !artistName.isEmpty {
            queryItems.append(URLQueryItem(name: "artist_name", value: artistName))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw LyricsError.invalidURL
        }

        let data = try await request(url)
        guard !data.isEmpty else { return nil }

        let results: [LRCLIBResponse]
        do {
            results = try JSONDecoder().decode([LRCLIBResponse].self, from: data)
        } catch {
            throw LyricsError.invalidResponse
        }
        guard !results.isEmpty else { return nil }

        let normalizedTitle = RussianText.normalizedKey(trackName)
        let normalizedArtist = RussianText.normalizedKey(artistName)
        let ranked = results.sorted { lhs, rhs in
            score(lhs, title: normalizedTitle, artist: normalizedArtist, duration: duration)
                > score(rhs, title: normalizedTitle, artist: normalizedArtist, duration: duration)
        }
        return ranked.first.map(Lyrics.init(from:))
    }

    private func score(
        _ response: LRCLIBResponse,
        title: String,
        artist: String,
        duration: TimeInterval?
    ) -> Double {
        var score = 0.0
        let candidateTitle = RussianText.normalizedKey(response.trackName)
        let candidateArtist = RussianText.normalizedKey(response.artistName)

        if candidateTitle == title { score += 40 }
        else if candidateTitle.contains(title) || title.contains(candidateTitle) { score += 18 }

        if !artist.isEmpty {
            if candidateArtist == artist { score += 30 }
            else if candidateArtist.contains(artist) || artist.contains(candidateArtist) { score += 12 }
        }

        if let duration, duration > 0, response.duration > 0 {
            let diff = abs(duration - Double(response.duration))
            if diff <= 2 { score += 20 }
            else if diff <= 8 { score += 8 }
            else if diff > 30 { score -= 10 }
        }

        if response.instrumental { score -= 5 }
        if response.syncedLyrics?.isEmpty == false { score += 3 }
        return score
    }

    // MARK: - Networking

    private func fetchLyrics(from url: URL) async throws -> Lyrics? {
        do {
            let data = try await request(url, allowNotFound: true)
            guard !data.isEmpty else { return nil }
            let response = try JSONDecoder().decode(LRCLIBResponse.self, from: data)
            return Lyrics(from: response)
        } catch LyricsError.notFound {
            return nil
        }
    }

    private func request(_ url: URL, allowNotFound: Bool = true) async throws -> Data {
        var request = URLRequest(url: url)
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
            throw LyricsError.invalidResponse
        }

        guard let http = response as? HTTPURLResponse else {
            throw LyricsError.invalidResponse
        }

        switch http.statusCode {
        case 200:
            return data
        case 404:
            if allowNotFound { throw LyricsError.notFound }
            return Data()
        case 429:
            throw LyricsError.rateLimitExceeded
        default:
            throw LyricsError.invalidResponse
        }
    }
}

// MARK: - Models

struct Lyrics: Sendable {
    let id: Int
    let trackName: String
    let artistName: String
    let albumName: String?
    let duration: Int
    let instrumental: Bool
    let plainLyrics: String?
    let syncedLyrics: String?
    let hasWordSync: Bool

    init(from response: LRCLIBResponse) {
        self.id = response.id
        self.trackName = response.trackName
        self.artistName = response.artistName
        self.albumName = response.albumName
        self.duration = response.duration
        self.instrumental = response.instrumental
        self.plainLyrics = response.plainLyrics
        self.syncedLyrics = response.syncedLyrics
        self.hasWordSync = response.hasWordSync ?? false
    }

    var hasSyncedLyrics: Bool {
        syncedLyrics?.isEmpty == false
    }

    var hasPlainLyrics: Bool {
        plainLyrics?.isEmpty == false
    }

    /// Parse synced lyrics into timed lines.
    var parsedLines: [LyricLine] {
        guard let syncedLyrics else { return [] }
        return LRCParser.parse(syncedLyrics)
    }
}

struct LyricLine: Identifiable, Sendable {
    let id = UUID()
    let timestamp: TimeInterval
    let text: String
}

struct LRCLIBResponse: Decodable {
    let id: Int
    let trackName: String
    let artistName: String
    let albumName: String?
    let duration: Int
    let instrumental: Bool
    let plainLyrics: String?
    let syncedLyrics: String?
    let hasWordSync: Bool?
}

enum LyricsError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case notFound
    case rateLimitExceeded

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Неверный URL"
        case .invalidResponse:
            return "Неверный ответ от сервера"
        case .notFound:
            return "Текст не найден"
        case .rateLimitExceeded:
            return "Превышен лимит запросов. Попробуйте позже."
        }
    }
}

// MARK: - LRC parser

enum LRCParser {
    /// Разбирает LRC. Поддерживает `[mm:ss]`, `[mm:ss.xx]`, `[mm:ss.xxx]`
    /// и несколько временных меток в одной строке.
    static func parse(_ lrc: String) -> [LyricLine] {
        let pattern = #"\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        var lines: [LyricLine] = []

        for rawLine in lrc.components(separatedBy: .newlines) {
            let range = NSRange(rawLine.startIndex..., in: rawLine)
            let matches = regex.matches(in: rawLine, range: range)
            guard let lastMatch = matches.last else { continue }

            let textRange = NSRange(
                location: lastMatch.range.location + lastMatch.range.length,
                length: max(0, range.length - lastMatch.range.location - lastMatch.range.length)
            )
            let text = (rawLine as NSString)
                .substring(with: textRange)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            for match in matches {
                guard match.numberOfRanges >= 3 else { continue }
                let minutes = Int((rawLine as NSString).substring(with: match.range(at: 1))) ?? 0
                let seconds = Int((rawLine as NSString).substring(with: match.range(at: 2))) ?? 0

                var fraction = 0.0
                if match.numberOfRanges > 3, match.range(at: 3).location != NSNotFound {
                    let rawFraction = (rawLine as NSString).substring(with: match.range(at: 3))
                    if let value = Double(rawFraction) {
                        switch rawFraction.count {
                        case 1: fraction = value / 10
                        case 2: fraction = value / 100
                        default: fraction = value / 1000
                        }
                    }
                }

                let timestamp = TimeInterval(minutes * 60 + seconds) + fraction
                lines.append(LyricLine(timestamp: timestamp, text: text))
            }
        }

        return lines.sorted { $0.timestamp < $1.timestamp }
    }
}
