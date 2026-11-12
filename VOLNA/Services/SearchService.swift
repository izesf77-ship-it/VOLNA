import Foundation

/// Сервис поиска музыки по нескольким провайдерам
actor SearchService {
    private let providerRegistry: ProviderRegistry
    private var currentSearchTask: Task<CombinedSearchResult, Error>?
    
    init(providerRegistry: ProviderRegistry) {
        self.providerRegistry = providerRegistry
    }
    
    /// Поиск по всем доступным провайдерам
    func search(
        query: String,
        type: SearchType = .all
    ) async throws -> CombinedSearchResult {
        // Cancel previous search if still running
        currentSearchTask?.cancel()
        
        let searchTask = Task { () -> CombinedSearchResult in
            let providers = await providerRegistry.allProviders
            
            // Search all providers in parallel
            let results = await withTaskGroup(
                of: (String, SearchResult?).self
            ) { group in
                for provider in providers {
                    group.addTask {
                        let providerID = await provider.id
                        do {
                            let result = try await provider.search(query: query, type: type)
                            return (providerID, result)
                        } catch {
                            print("❌ Search failed for \(providerID): \(error)")
                            return (providerID, nil)
                        }
                    }
                }
                
                var allResults: [String: SearchResult] = [:]
                for await (providerID, result) in group {
                    if let result = result {
                        allResults[providerID] = result
                    }
                }
                return allResults
            }
            
            // Combine and deduplicate results
            return combineResults(results)
        }
        
        currentSearchTask = searchTask
        return try await searchTask.value
    }
    
    /// Cancel current search
    func cancelSearch() {
        currentSearchTask?.cancel()
        currentSearchTask = nil
    }
    
    // MARK: - Private Methods
    
    private func combineResults(
        _ results: [String: SearchResult]
    ) -> CombinedSearchResult {
        var allTracks: [Track] = []
        var allAlbums: [Album] = []
        var allArtists: [Artist] = []
        
        for (_, result) in results {
            allTracks.append(contentsOf: result.tracks)
            allAlbums.append(contentsOf: result.albums)
            allArtists.append(contentsOf: result.artists)
        }
        
        // Deduplicate tracks
        let uniqueTracks = deduplicateTracks(allTracks)
        
        // Deduplicate albums
        let uniqueAlbums = deduplicateAlbums(allAlbums)
        
        // Deduplicate artists
        let uniqueArtists = deduplicateArtists(allArtists)
        
        return CombinedSearchResult(
            tracks: uniqueTracks,
            albums: uniqueAlbums,
            artists: uniqueArtists,
            providerResults: results
        )
    }
    
    private func deduplicateTracks(_ tracks: [Track]) -> [Track] {
        var seen = Set<String>()
        var unique: [Track] = []
        
        for track in tracks {
            // Create normalized key for matching
            let key = normalizeKey("\(track.title)_\(track.artist)")
            
            if !seen.contains(key) {
                seen.insert(key)
                unique.append(track)
            } else {
                // Track already exists, merge stream sources
                if let index = unique.firstIndex(where: {
                    normalizeKey("\($0.title)_\($0.artist)") == key
                }) {
                    var existingTrack = unique[index]
                    existingTrack.availableStreams.append(contentsOf: track.availableStreams)
                    unique[index] = existingTrack
                }
            }
        }
        
        return unique
    }
    
    private func deduplicateAlbums(_ albums: [Album]) -> [Album] {
        var seen = Set<String>()
        var unique: [Album] = []
        
        for album in albums {
            let key = normalizeKey("\(album.title)_\(album.artist)")
            
            if !seen.contains(key) {
                seen.insert(key)
                unique.append(album)
            }
        }
        
        return unique
    }
    
    private func deduplicateArtists(_ artists: [Artist]) -> [Artist] {
        var seen = Set<String>()
        var unique: [Artist] = []
        
        for artist in artists {
            let key = normalizeKey(artist.name)
            
            if !seen.contains(key) {
                seen.insert(key)
                unique.append(artist)
            }
        }
        
        return unique
    }
    
    private func normalizeKey(_ string: String) -> String {
        // Normalize for comparison: lowercase, remove extra spaces, transliterate
        return string
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "  ", with: " ")
            .folding(options: .diacriticInsensitive, locale: .current)
    }
}

/// Объединённый результат поиска со всех провайдеров
struct CombinedSearchResult: Sendable {
    let tracks: [Track]
    let albums: [Album]
    let artists: [Artist]
    let providerResults: [String: SearchResult]
    
    var isEmpty: Bool {
        tracks.isEmpty && albums.isEmpty && artists.isEmpty
    }
    
    var totalResults: Int {
        tracks.count + albums.count + artists.count
    }
}
