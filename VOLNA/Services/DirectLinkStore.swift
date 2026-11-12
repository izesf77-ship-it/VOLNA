import Foundation
import Observation

/// Локальное хранилище прямых аудиоссылок. Данные лежат в JSON-файле
/// Documents/direct_links.json и не покидают устройство.
@MainActor
@Observable
final class DirectLinkStore {
    private(set) var links: [DirectLink] = []
    private(set) var lastError: String?
    private(set) var isAdding = false

    private let fileURL: URL
    private let validator = DirectAudioValidator()

    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.fileURL = documents
            .appendingPathComponent("VOLNA", isDirectory: true)
            .appendingPathComponent("direct_links.json")
        load()
    }

    @discardableResult
    func add(
        title: String,
        artist: String,
        urlString: String,
        license: LicenseType,
        licenseURL: URL?
    ) async -> DirectLink? {
        lastError = nil
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanTitle.isEmpty else {
            lastError = "Укажите название композиции"
            return nil
        }
        guard let url = URL(string: cleanURL), url.scheme?.lowercased() == "https" else {
            lastError = "Введите корректную HTTPS-ссылку на аудио"
            return nil
        }

        isAdding = true
        defer { isAdding = false }

        do {
            let validation = try await validator.validate(url)
            let link = DirectLink(
                title: cleanTitle,
                artist: cleanArtist.isEmpty ? "Неизвестный исполнитель" : cleanArtist,
                url: validation.finalURL,
                format: validation.format,
                contentType: validation.contentType,
                license: license,
                licenseURL: licenseURL
            )
            links.insert(link, at: 0)
            save()
            return link
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func remove(id: String) {
        links.removeAll { $0.id == id }
        save()
    }

    func removeAll() {
        links.removeAll()
        save()
    }

    private func load() {
        do {
            guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
            let data = try Data(contentsOf: fileURL)
            links = try JSONDecoder().decode([DirectLink].self, from: data)
        } catch {
            lastError = "Не удалось загрузить прямые ссылки: \(error.localizedDescription)"
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
            let data = try encoder.encode(links)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            lastError = "Не удалось сохранить прямые ссылки: \(error.localizedDescription)"
        }
    }
}
