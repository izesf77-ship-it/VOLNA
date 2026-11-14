import Foundation
import Observation

/// Избранные радиостанции. Как и медиатека VOLNA, это обычный JSON-файл в
/// Documents: избранное переживает перезапуск и не требует сети или аккаунта.
@MainActor
@Observable
final class RadioFavoritesStore {
    private(set) var stations: [RadioStation] = []
    private(set) var lastError: String?

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.fileURL = documents
                .appendingPathComponent("VOLNA", isDirectory: true)
                .appendingPathComponent("radio-favorites.json")
        }
        load()
    }

    var isEmpty: Bool { stations.isEmpty }
    var count: Int { stations.count }

    func isFavorite(_ station: RadioStation) -> Bool {
        isFavorite(id: station.id)
    }

    func isFavorite(id: String) -> Bool {
        stations.contains { $0.id == id }
    }

    @discardableResult
    func toggle(_ station: RadioStation) -> Bool {
        if let index = stations.firstIndex(where: { $0.id == station.id }) {
            stations.remove(at: index)
            save()
            return false
        }
        stations.insert(station, at: 0)
        if stations.count > 200 {
            stations = Array(stations.prefix(200))
        }
        save()
        return true
    }

    func add(_ station: RadioStation) {
        guard !isFavorite(station) else { return }
        stations.insert(station, at: 0)
        if stations.count > 200 {
            stations = Array(stations.prefix(200))
        }
        save()
    }

    func remove(id: String) {
        let before = stations.count
        stations.removeAll { $0.id == id }
        guard stations.count != before else { return }
        save()
    }

    func removeAll() {
        guard !stations.isEmpty else { return }
        stations.removeAll()
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let snapshot = try JSONDecoder().decode(RadioFavoritesSnapshot.self, from: data)
            var seen = Set<String>()
            stations = snapshot.stations.filter { station in
                let key = station.id.lowercased()
                guard !key.isEmpty, seen.insert(key).inserted else { return false }
                return true
            }
            lastError = nil
        } catch {
            lastError = "Не удалось загрузить избранные радиостанции: \(error.localizedDescription)"
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(RadioFavoritesSnapshot(stations: stations))
            try data.write(to: fileURL, options: .atomic)
            lastError = nil
        } catch {
            lastError = "Не удалось сохранить избранные радиостанции: \(error.localizedDescription)"
        }
    }
}

private struct RadioFavoritesSnapshot: Codable {
    var version: Int = 1
    let stations: [RadioStation]
}
