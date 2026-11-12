import Foundation

/// Протокол музыкального провайдера
/// Все провайдеры должны быть actors для thread-safety
protocol MusicProvider: Actor {
    /// Уникальный идентификатор провайдера
    var id: String { get }
    
    /// Человекочитаемое название
    var name: String { get }
    
    /// Возможности провайдера
    var capabilities: ProviderCapabilities { get }
    
    /// Поиск композиций, альбомов или исполнителей
    func search(query: String, type: SearchType) async throws -> SearchResult
    
    /// Получить URL потока для композиции
    func resolveStream(for track: Track) async throws -> StreamSource?
    
    /// Получить информацию об исполнителе (опционально)
    func fetchArtist(id: String) async throws -> Artist?
    
    /// Получить информацию об альбоме (опционально)
    func fetchAlbum(id: String) async throws -> Album?
}

/// Возможности провайдера
struct ProviderCapabilities: Sendable {
    let supportsSearch: Bool
    let supportsStreaming: Bool
    let supportsArtwork: Bool
    let supportsAlbums: Bool
    let supportsArtists: Bool
    let supportsLyrics: Bool
    let supportsDownload: Bool
    let requiresAuthentication: Bool
    
    static let full = ProviderCapabilities(
        supportsSearch: true,
        supportsStreaming: true,
        supportsArtwork: true,
        supportsAlbums: true,
        supportsArtists: true,
        supportsLyrics: false,
        supportsDownload: true,
        requiresAuthentication: false
    )
    
    static let searchOnly = ProviderCapabilities(
        supportsSearch: true,
        supportsStreaming: false,
        supportsArtwork: false,
        supportsAlbums: false,
        supportsArtists: false,
        supportsLyrics: false,
        supportsDownload: false,
        requiresAuthentication: false
    )
}

/// Тип поиска
enum SearchType: String, Sendable {
    case track = "track"
    case album = "album"
    case artist = "artist"
    case all = "all"
}

/// Результат поиска
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

/// Ошибки провайдера
enum ProviderError: Error, LocalizedError {
    case notSupported
    case networkError(Error)
    case invalidResponse
    case authenticationRequired
    case rateLimitExceeded
    case resourceNotFound
    case invalidConfiguration
    
    var errorDescription: String? {
        switch self {
        case .notSupported:
            return "Функция не поддерживается этим провайдером"
        case .networkError(let error):
            return "Ошибка сети: \(error.localizedDescription)"
        case .invalidResponse:
            return "Неверный ответ от сервера"
        case .authenticationRequired:
            return "Требуется аутентификация"
        case .rateLimitExceeded:
            return "Превышен лимит запросов"
        case .resourceNotFound:
            return "Ресурс не найден"
        case .invalidConfiguration:
            return "Неверная конфигурация провайдера"
        }
    }
}
