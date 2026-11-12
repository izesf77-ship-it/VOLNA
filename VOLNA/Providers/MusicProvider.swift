import Foundation

/// Протокол музыкального провайдера. Все провайдеры — actors.
protocol MusicProvider: Actor {
    nonisolated var id: String { get }
    nonisolated var name: String { get }
    nonisolated var capabilities: ProviderCapabilities { get }

    func search(query: String, type: SearchType) async throws -> SearchResult
    func resolveStream(for track: Track) async throws -> StreamSource?
    func fetchArtist(id: String) async throws -> Artist?
    func fetchAlbum(id: String) async throws -> Album?
    func healthCheck() async -> ProviderHealth
}

extension MusicProvider {
    func fetchArtist(id: String) async throws -> Artist? {
        throw ProviderError.notSupported
    }

    func fetchAlbum(id: String) async throws -> Album? {
        throw ProviderError.notSupported
    }

    func resolveStream(for track: Track) async throws -> StreamSource? {
        track.playableStreams.first
    }

    func healthCheck() async -> ProviderHealth {
        let start = ContinuousClock.now
        do {
            _ = try await search(query: "music", type: .track)
            let elapsed = start.duration(to: .now)
            return ProviderHealth(
                isAvailable: true,
                latency: elapsed.timeInterval,
                message: "Поиск отвечает",
                sampleTrackCount: nil
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
}

struct ProviderCapabilities: Sendable {
    let supportsSearch: Bool
    let supportsStreaming: Bool
    let supportsArtwork: Bool
    let supportsAlbums: Bool
    let supportsArtists: Bool
    let supportsLyrics: Bool
    let supportsDownload: Bool
    let requiresAuthentication: Bool
    let supportsRussian: Bool
    let isLocal: Bool

    init(
        supportsSearch: Bool = true,
        supportsStreaming: Bool = true,
        supportsArtwork: Bool = false,
        supportsAlbums: Bool = false,
        supportsArtists: Bool = false,
        supportsLyrics: Bool = false,
        supportsDownload: Bool = false,
        requiresAuthentication: Bool = false,
        supportsRussian: Bool = false,
        isLocal: Bool = false
    ) {
        self.supportsSearch = supportsSearch
        self.supportsStreaming = supportsStreaming
        self.supportsArtwork = supportsArtwork
        self.supportsAlbums = supportsAlbums
        self.supportsArtists = supportsArtists
        self.supportsLyrics = supportsLyrics
        self.supportsDownload = supportsDownload
        self.requiresAuthentication = requiresAuthentication
        self.supportsRussian = supportsRussian
        self.isLocal = isLocal
    }

    static let full = ProviderCapabilities(
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

    static let searchOnly = ProviderCapabilities(
        supportsSearch: true,
        supportsStreaming: false,
        supportsArtwork: false,
        supportsAlbums: false,
        supportsArtists: false,
        supportsLyrics: false,
        supportsDownload: false,
        requiresAuthentication: false,
        supportsRussian: false,
        isLocal: false
    )
}

enum SearchType: String, Sendable, CaseIterable {
    case track
    case album
    case artist
    case all
}

struct SearchResult: Sendable {
    let tracks: [Track]
    let albums: [Album]
    let artists: [Artist]
    let providerID: String

    init(
        tracks: [Track] = [],
        albums: [Album] = [],
        artists: [Artist] = [],
        providerID: String
    ) {
        self.tracks = tracks
        self.albums = albums
        self.artists = artists
        self.providerID = providerID
    }

    var isEmpty: Bool {
        tracks.isEmpty && albums.isEmpty && artists.isEmpty
    }

    var totalResults: Int {
        tracks.count + albums.count + artists.count
    }
}

struct ProviderHealth: Sendable {
    let isAvailable: Bool
    let latency: TimeInterval?
    let message: String?
    let sampleTrackCount: Int?

    var latencyText: String? {
        guard let latency else { return nil }
        if latency < 1 {
            return "\(Int(latency * 1000)) мс"
        }
        return String(format: "%.1f с", latency)
    }
}

enum ProviderError: Error, LocalizedError {
    case notSupported
    case networkError(Error)
    case invalidResponse(String? = nil)
    case authenticationRequired
    case rateLimitExceeded
    case resourceNotFound
    case invalidConfiguration
    case cancelled

    var errorDescription: String? {
        switch self {
        case .notSupported:
            return "Функция не поддерживается этим источником"
        case .networkError(let error):
            return "Ошибка сети: \(error.localizedDescription)"
        case .invalidResponse(let detail):
            if let detail, !detail.isEmpty {
                return "Источник вернул неверный ответ: \(detail)"
            }
            return "Источник вернул неверный ответ"
        case .authenticationRequired:
            return "Требуется авторизация"
        case .rateLimitExceeded:
            return "Превышен лимит запросов"
        case .resourceNotFound:
            return "Ресурс не найден"
        case .invalidConfiguration:
            return "Неверная конфигурация источника"
        case .cancelled:
            return "Запрос отменён"
        }
    }
}

extension Duration {
    var timeInterval: TimeInterval {
        let components = self.components
        return TimeInterval(components.seconds) + TimeInterval(components.attoseconds) / 1_000_000_000_000_000_000
    }
}
