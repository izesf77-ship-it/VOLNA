import Foundation

/// Сервис управления локальной медиатекой
actor LibraryService {
    private let fileManager = FileManager.default
    private let libraryDirectory: URL
    
    // State
    private var favorites: Set<String> = []
    private var playlists: [Playlist] = []
    private var history: [Track] = []
    
    init() {
        // Get documents directory
        let documentsURL = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
        
        self.libraryDirectory = documentsURL.appendingPathComponent("Library")
        
        // Create library directory if needed
        try? fileManager.createDirectory(
            at: libraryDirectory,
            withIntermediateDirectories: true
        )
        
        // Load data
        Task {
            await loadLibrary()
        }
    }
    
    // MARK: - Favorites
    
    func isFavorite(trackID: String) -> Bool {
        favorites.contains(trackID)
    }
    
    func toggleFavorite(trackID: String) {
        if favorites.contains(trackID) {
            favorites.remove(trackID)
        } else {
            favorites.insert(trackID)
        }
        saveFavorites()
    }
    
    func addFavorite(trackID: String) {
        favorites.insert(trackID)
        saveFavorites()
    }
    
    func removeFavorite(trackID: String) {
        favorites.remove(trackID)
        saveFavorites()
    }
    
    func getFavorites() -> Set<String> {
        favorites
    }
    
    // MARK: - Playlists
    
    func getPlaylists() -> [Playlist] {
        playlists
    }
    
    func createPlaylist(title: String) -> Playlist {
        let playlist = Playlist(title: title)
        playlists.append(playlist)
        savePlaylists()
        return playlist
    }
    
    func deletePlaylist(id: String) {
        playlists.removeAll { $0.id == id }
        savePlaylists()
    }
    
    func addTrack(_ track: Track, to playlistID: String) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }) else {
            return
        }
        
        var playlist = playlists[index]
        playlist.tracks.append(track)
        playlist.modifiedAt = Date()
        playlists[index] = playlist
        
        savePlaylists()
    }
    
    func removeTrack(trackID: String, from playlistID: String) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }) else {
            return
        }
        
        var playlist = playlists[index]
        playlist.tracks.removeAll { $0.id == trackID }
        playlist.modifiedAt = Date()
        playlists[index] = playlist
        
        savePlaylists()
    }
    
    // MARK: - History
    
    func addToHistory(_ track: Track) {
        // Remove if already in history
        history.removeAll { $0.id == track.id }
        
        // Add to beginning
        history.insert(track, at: 0)
        
        // Limit history to 100 tracks
        if history.count > 100 {
            history = Array(history.prefix(100))
        }
        
        saveHistory()
    }
    
    func getHistory() -> [Track] {
        history
    }
    
    func clearHistory() {
        history.removeAll()
        saveHistory()
    }
    
    // MARK: - Persistence
    
    private func loadLibrary() {
        loadFavorites()
        loadPlaylists()
        loadHistory()
    }
    
    private func loadFavorites() {
        let url = libraryDirectory.appendingPathComponent("favorites.json")
        guard let data = try? Data(contentsOf: url) else {
            return
        }
        
        do {
            let decoder = JSONDecoder()
            favorites = try decoder.decode(Set<String>.self, from: data)
            print("✅ Loaded \(favorites.count) favorites")
        } catch {
            print("❌ Failed to load favorites: \(error)")
        }
    }
    
    private func saveFavorites() {
        let url = libraryDirectory.appendingPathComponent("favorites.json")
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(favorites)
            try data.write(to: url, options: .atomic)
        } catch {
            print("❌ Failed to save favorites: \(error)")
        }
    }
    
    private func loadPlaylists() {
        let url = libraryDirectory.appendingPathComponent("playlists.json")
        guard let data = try? Data(contentsOf: url) else {
            return
        }
        
        do {
            let decoder = JSONDecoder()
            playlists = try decoder.decode([Playlist].self, from: data)
            print("✅ Loaded \(playlists.count) playlists")
        } catch {
            print("❌ Failed to load playlists: \(error)")
        }
    }
    
    private func savePlaylists() {
        let url = libraryDirectory.appendingPathComponent("playlists.json")
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(playlists)
            try data.write(to: url, options: .atomic)
        } catch {
            print("❌ Failed to save playlists: \(error)")
        }
    }
    
    private func loadHistory() {
        let url = libraryDirectory.appendingPathComponent("history.json")
        guard let data = try? Data(contentsOf: url) else {
            return
        }
        
        do {
            let decoder = JSONDecoder()
            history = try decoder.decode([Track].self, from: data)
            print("✅ Loaded \(history.count) history items")
        } catch {
            print("❌ Failed to load history: \(error)")
        }
    }
    
    private func saveHistory() {
        let url = libraryDirectory.appendingPathComponent("history.json")
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(history)
            try data.write(to: url, options: .atomic)
        } catch {
            print("❌ Failed to save history: \(error)")
        }
    }
}
