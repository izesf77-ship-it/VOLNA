import Foundation

/// Сервис получения текстов песен из LRCLIB
actor LyricsService {
    private let baseURL = "https://lrclib.net/api"
    private let urlSession: URLSession
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.requestCachePolicy = .returnCacheDataElseLoad
        self.urlSession = URLSession(configuration: config)
    }
    
    /// Поиск текста по информации о композиции
    func searchLyrics(
        trackName: String,
        artistName: String,
        albumName: String? = nil,
        duration: TimeInterval? = nil
    ) async throws -> Lyrics? {
        var components = URLComponents(string: "\(baseURL)/get")!
        
        var queryItems = [
            URLQueryItem(name: "track_name", value: trackName),
            URLQueryItem(name: "artist_name", value: artistName)
        ]
        
        if let albumName = albumName {
            queryItems.append(URLQueryItem(name: "album_name", value: albumName))
        }
        
        if let duration = duration {
            queryItems.append(URLQueryItem(name: "duration", value: "\(Int(duration))"))
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw LyricsError.invalidURL
        }
        
        return try await fetchLyrics(from: url)
    }
    
    /// Получить текст по ID LRCLIB
    func getLyrics(id: Int) async throws -> Lyrics {
        let url = URL(string: "\(baseURL)/get/\(id)")!
        
        guard let lyrics = try await fetchLyrics(from: url) else {
            throw LyricsError.notFound
        }
        
        return lyrics
    }
    
    // MARK: - Private Methods
    
    private func fetchLyrics(from url: URL) async throws -> Lyrics? {
        var request = URLRequest(url: url)
        request.setValue("VOLNA/0.1.0 (https://github.com/yourusername/VOLNA)", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LyricsError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            let lrcResponse = try decoder.decode(LRCLIBResponse.self, from: data)
            return Lyrics(from: lrcResponse)
            
        case 404:
            return nil // Lyrics not found
            
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
        syncedLyrics != nil && !syncedLyrics!.isEmpty
    }
    
    var hasPlainLyrics: Bool {
        plainLyrics != nil && !plainLyrics!.isEmpty
    }
    
    /// Parse synced lyrics into timed lines
    var parsedLines: [LyricLine] {
        guard let syncedLyrics = syncedLyrics else { return [] }
        
        return LRCParser.parse(syncedLyrics)
    }
}

struct LyricLine: Identifiable, Sendable {
    let id = UUID()
    let timestamp: TimeInterval
    let text: String
}

private struct LRCLIBResponse: Decodable {
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

// MARK: - LRC Parser

enum LRCParser {
    /// Parse LRC format into timed lines
    static func parse(_ lrc: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        
        let lrcLines = lrc.components(separatedBy: .newlines)
        
        for line in lrcLines {
            // Match pattern [mm:ss.xx] text
            let pattern = #"\[(\d+):(\d+)\.(\d+)\]\s*(.*)$"#
            
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(
                    in: line,
                    range: NSRange(line.startIndex..., in: line)
                  ),
                  match.numberOfRanges == 5 else {
                continue
            }
            
            let minutes = Int((line as NSString).substring(with: match.range(at: 1))) ?? 0
            let seconds = Int((line as NSString).substring(with: match.range(at: 2))) ?? 0
            let centiseconds = Int((line as NSString).substring(with: match.range(at: 3))) ?? 0
            let text = (line as NSString).substring(with: match.range(at: 4))
            
            let timestamp = TimeInterval(minutes * 60 + seconds) + TimeInterval(centiseconds) / 100.0
            
            lines.append(LyricLine(timestamp: timestamp, text: text))
        }
        
        return lines.sorted { $0.timestamp < $1.timestamp }
    }
}
