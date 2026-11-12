import Foundation
import Observation

/// Локальная медиатека VOLNA. Всё хранится в JSON-файле в Documents.
/// Никаких баз данных, аккаунтов и серверов.
@MainActor
@Observable
final class LibraryService {
    private(set) var favorites: [Track] = []
    private(set) var playlists: [Playlist] = []
    private(set) var history: [Track] = []
    private(set) var lastError: String?

    private let fileURL: URL

    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.fileURL = documents
            .appendingPathComponent("VOLNA", isDirectory: true)
            .appendingPathComponent("library.json")
        load()
    }

    // MARK: - Favorites

    func isFavorite(_ track: Track) -> Bool {
        favorites.contains { $0.id == track.id }
    }

    @discardableResult
    func toggleFavorite(_ track: Track) -> Bool {
        if let index = favorites.firstIndex(where: { $0.id == track.id }) {
            favorites.remove(at: index)
            save()
            return false
        }
        favorites.insert(track, at: 0)
        save()
        return true
    }

    func removeFavorite(id: String) {
        favorites.removeAll { $0.id == id }
        save()
    }

    // MARK: - Playlists

    @discardableResult
    func createPlaylist(title: String) -> Playlist {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = "Плейлист \(playlists.count + 1)"
        let playlist = Playlist(title: clean.isEmpty ? fallback : clean)
        playlists.insert(playlist, at: 0)
        save()
        return playlist
    }

    func deletePlaylist(id: String) {
        playlists.removeAll { $0.id == id }
        save()
    }

    func renamePlaylist(id: String, title: String) {
        guard let index = playlists.firstIndex(where: { $0.id == id }) else { return }
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        playlists[index].title = clean
        playlists[index].modifiedAt = Date()
        save()
    }

    func addTrack(_ track: Track, to playlistID: String) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        guard !playlists[index].tracks.contains(where: { $0.id == track.id }) else { return }
        playlists[index].tracks.append(track)
        playlists[index].modifiedAt = Date()
        if playlists[index].artworkURL == nil {
            playlists[index].artworkURL = track.artworkURL
        }
        save()
    }

    func removeTrack(_ trackID: String, from playlistID: String) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        playlists[index].tracks.removeAll { $0.id == trackID }
        playlists[index].modifiedAt = Date()
        save()
    }

    func playlist(id: String) -> Playlist? {
        playlists.first { $0.id == id }
    }

    // MARK: - History

    func recordPlayed(_ track: Track) {
        history.removeAll { $0.id == track.id }
        history.insert(track, at: 0)
        if history.count > 100 {
            history = Array(history.prefix(100))
        }
        save()
    }

    func clearHistory() {
        history.removeAll()
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let snapshot = try JSONDecoder().decode(LibrarySnapshot.self, from: data)
            favorites = snapshot.favorites
            playlists = snapshot.playlists
            history = snapshot.history
        } catch {
            lastError = "Не удалось загрузить медиатеку: \(error.localizedDescription)"
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let snapshot = LibrarySnapshot(
                favorites: favorites,
                playlists: playlists,
                history: history
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            lastError = "Не удалось сохранить медиатеку: \(error.localizedDescription)"
        }
    }
}

private struct LibrarySnapshot: Codable {
    let favorites: [Track]
    let playlists: [Playlist]
    let history: [Track]
}
