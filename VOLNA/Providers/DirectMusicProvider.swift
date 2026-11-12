import Foundation

/// Пользовательский источник прямых аудиоссылок.
actor DirectMusicProvider: MusicProvider {
    nonisolated let id = "direct"
    nonisolated let name = "Прямые ссылки"

    nonisolated let capabilities = ProviderCapabilities(
        supportsSearch: true,
        supportsStreaming: true,
        supportsArtwork: false,
        supportsAlbums: false,
        supportsArtists: false,
        supportsLyrics: false,
        supportsDownload: false,
        requiresAuthentication: false,
        supportsRussian: true,
        isLocal: true
    )

    private var links: [DirectLink]

    init(links: [DirectLink] = []) {
        self.links = links
    }

    func updateLinks(_ links: [DirectLink]) {
        self.links = links
    }

    func search(query: String, type: SearchType) async throws -> SearchResult {
        guard type == .track || type == .all else {
            return SearchResult(providerID: id)
        }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = RussianText.normalizedKey(trimmed)
        let matching: [DirectLink]
        if normalized.isEmpty {
            matching = links
        } else {
            matching = links.filter { link in
                let haystack = RussianText.normalizedKey("\(link.title) \(link.artist)")
                return haystack.contains(normalized) || normalized.contains(haystack)
            }
        }
        return SearchResult(tracks: matching.map(\.track), providerID: id)
    }

    func resolveStream(for track: Track) async throws -> StreamSource? {
        guard track.providerID == id else {
            throw ProviderError.invalidConfiguration
        }
        return track.playableStreams.first
    }

    func healthCheck() async -> ProviderHealth {
        ProviderHealth(
            isAvailable: true,
            latency: 0,
            message: links.isEmpty
                ? "Прямые ссылки ещё не добавлены"
                : "Локальный источник: \(links.count) ссылок",
            sampleTrackCount: links.count
        )
    }
}
