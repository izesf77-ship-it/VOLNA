import Foundation
import Observation

/// Недавние поисковые запросы. Хранятся только в UserDefaults на устройстве,
/// без аккаунта, аналитики и сервера.
@MainActor
@Observable
final class SearchHistoryStore {
    private(set) var queries: [String] = []

    private let defaults = UserDefaults.standard
    private let storeKey = "volna.search.history.v1"
    private let limit = 8

    init() {
        guard let data = defaults.data(forKey: storeKey),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return
        }
        queries = Array(decoded.prefix(limit))
    }

    func record(_ query: String) {
        let clean = query
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count >= 2 else { return }

        queries.removeAll { $0.caseInsensitiveCompare(clean) == .orderedSame }
        queries.insert(clean, at: 0)
        if queries.count > limit {
            queries = Array(queries.prefix(limit))
        }
        save()
    }

    func remove(_ query: String) {
        queries.removeAll { $0 == query }
        save()
    }

    func clear() {
        queries = []
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(queries) else { return }
        defaults.set(data, forKey: storeKey)
    }
}
