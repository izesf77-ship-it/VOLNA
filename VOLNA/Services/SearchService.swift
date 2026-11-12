import Foundation
import Observation

/// Фильтры поиска, применяемые после объединения результатов.
struct SearchFilters: Equatable, Sendable {
    var language: String? = nil       // "ru" — только русскоязычные
    var genre: String? = nil          // ключевое слово жанра
    var onlyPlayable: Bool = true
    var preferRussian: Bool = true    // поднимать русскоязычные записи в выдаче

    static let `default` = SearchFilters()
}

struct GenreOption: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let keywords: [String]
}

enum GenreCatalog {
    static let all: [GenreOption] = [
        GenreOption(id: "rock", title: "Рок", keywords: ["rock", "рок", "punk", "metal", "метал"]),
        GenreOption(id: "rap", title: "Рэп", keywords: ["rap", "hip", "рэп", "хип"]),
        GenreOption(id: "electronic", title: "Электроника", keywords: ["electronic", "electro", "techno", "house", "ambient", "электрон", "техно"]),
        GenreOption(id: "folk", title: "Фолк", keywords: ["folk", "фолк", "народ", "traditional", "этн"]),
        GenreOption(id: "classical", title: "Классика", keywords: ["classical", "classic", "классик", "opera", "симфон", "baroque"]),
        GenreOption(id: "indie", title: "Инди", keywords: ["indie", "инди", "alternative", "альтернатив"]),
        GenreOption(id: "jazz", title: "Джаз", keywords: ["jazz", "джаз", "blues", "блюз"]),
        GenreOption(id: "pop", title: "Поп", keywords: ["pop", "поп", "dance", "танц"]),
        GenreOption(id: "soundtrack", title: "Саундтреки", keywords: ["soundtrack", "score", "саундтрек", "cinematic"]),
        GenreOption(id: "instrumental", title: "Инструментал", keywords: ["instrumental", "инструментал", "piano", "фортепиано"])
    ]

    static func option(for id: String?) -> GenreOption? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }
}

struct ProviderSearchIssue: Identifiable, Equatable, Sendable {
    let id: String
    let providerName: String
    let message: String
}

struct SearchProviderStat: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let count: Int
    let milliseconds: Int
}

/// Единый поиск по всем включённым источникам.
///
/// Поиск выполняется параллельно. Ошибка одного источника не прерывает
/// остальные: она сохраняется в `issues` и показывается в интерфейсе отдельно.
@MainActor
@Observable
final class SearchService {
    private let registry: ProviderRegistry
    private var searchTask: Task<Void, Never>?
    private var generation = UUID()

    private(set) var isSearching = false
    private(set) var tracks: [Track] = []
    private(set) var albums: [Album] = []
    private(set) var artists: [Artist] = []
    private(set) var issues: [ProviderSearchIssue] = []
    private(set) var stats: [SearchProviderStat] = []
    private(set) var lastQuery = ""
    private(set) var lastFilters = SearchFilters.default
    private(set) var lastCompletedAt: Date?

    static let popularQueries: [String] = [
        "русский рок", "русский рэп", "русское инди", "russian folk",
        "русская классика", "Кино", "rock", "jazz", "piano", "ambient"
    ]

    static let russianQueries: [String] = [
        "русский рок", "русский рэп", "русское инди", "русская электроника",
        "русские народные песни", "русская классическая музыка", "russian rock",
        "russian folk", "russian indie", "russian classical"
    ]

    init(providerRegistry: ProviderRegistry) {
        self.registry = providerRegistry
    }

    var hasResults: Bool {
        !tracks.isEmpty || !albums.isEmpty || !artists.isEmpty
    }

    var totalTracks: Int { tracks.count }

    /// Запускает поиск. Предыдущий запрос отменяется.
    func search(
        query: String,
        type: SearchType = .all,
        filters: SearchFilters = .default,
        enabledProviderIDs: Set<String>
    ) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            reset()
            return
        }

        searchTask?.cancel()
        let token = UUID()
        generation = token

        lastQuery = trimmed
        lastFilters = filters
        isSearching = true
        issues = []
        stats = []

        let providers = registry.searchableProviders.filter {
            enabledProviderIDs.contains($0.id) && $0.capabilities.supportsSearch
        }

        guard !providers.isEmpty else {
            tracks = []
            albums = []
            artists = []
            issues = [
                ProviderSearchIssue(
                    id: "no-providers",
                    providerName: "Источники",
                    message: "Все музыкальные источники отключены. Включите хотя бы один в настройках."
                )
            ]
            isSearching = false
            return
        }

        let variants = RussianText.queryVariants(trimmed)

        let task = Task { [weak self] in
            guard let self else { return }
            let outcomes = await Self.execute(
                providers: providers,
                variants: variants,
                type: type
            )
            guard !Task.isCancelled, self.generation == token else { return }
            self.apply(outcomes: outcomes, query: trimmed, filters: filters)
        }
        searchTask = task
    }

    func reset() {
        searchTask?.cancel()
        generation = UUID()
        isSearching = false
        tracks = []
        albums = []
        artists = []
        issues = []
        stats = []
        lastQuery = ""
        lastCompletedAt = nil
    }

    // MARK: - Execution

    nonisolated private static func execute(
        providers: [any MusicProvider],
        variants: [String],
        type: SearchType
    ) async -> [ProviderOutcome] {
        await withTaskGroup(of: ProviderOutcome.self, returning: [ProviderOutcome].self) { group in
            for provider in providers {
                group.addTask {
                    let start = ContinuousClock.now
                    let providerID = provider.id
                    let providerName = provider.name

                    var tracks: [Track] = []
                    var albums: [Album] = []
                    var artists: [Artist] = []
                    var firstError: Error?

                    for variant in variants {
                        if Task.isCancelled {
                            return .cancelled(providerID: providerID, name: providerName)
                        }
                        do {
                            let result = try await provider.search(query: variant, type: type)
                            tracks.append(contentsOf: result.tracks)
                            albums.append(contentsOf: result.albums)
                            artists.append(contentsOf: result.artists)
                        } catch is CancellationError {
                            return .cancelled(providerID: providerID, name: providerName)
                        } catch {
                            if firstError == nil { firstError = error }
                        }
                    }

                    let latency = start.duration(to: .now).timeInterval
                    if tracks.isEmpty, albums.isEmpty, artists.isEmpty, let firstError {
                        return .failure(
                            providerID: providerID,
                            name: providerName,
                            message: firstError.localizedDescription
                        )
                    }

                    return .success(
                        providerID: providerID,
                        name: providerName,
                        result: SearchResult(
                            tracks: tracks,
                            albums: albums,
                            artists: artists,
                            providerID: providerID
                        ),
                        milliseconds: max(0, Int((latency * 1000).rounded()))
                    )
                }
            }

            var results: [ProviderOutcome] = []
            for await outcome in group {
                results.append(outcome)
            }
            return results
        }
    }

    private func apply(
        outcomes: [ProviderOutcome],
        query: String,
        filters: SearchFilters
    ) {
        var rawTracks: [Track] = []
        var rawAlbums: [Album] = []
        var rawArtists: [Artist] = []
        var newIssues: [ProviderSearchIssue] = []
        var newStats: [SearchProviderStat] = []

        for outcome in outcomes {
            switch outcome {
            case .success(let providerID, let name, let result, let milliseconds):
                rawTracks.append(contentsOf: result.tracks)
                rawAlbums.append(contentsOf: result.albums)
                rawArtists.append(contentsOf: result.artists)
                newStats.append(
                    SearchProviderStat(
                        id: providerID,
                        name: name,
                        count: result.tracks.count + result.albums.count + result.artists.count,
                        milliseconds: milliseconds
                    )
                )
            case .failure(let providerID, let name, let message):
                newIssues.append(
                    ProviderSearchIssue(
                        id: providerID,
                        providerName: name,
                        message: message
                    )
                )
            case .cancelled:
                continue
            }
        }

        if Task.isCancelled { return }

        var mergedTracks = SearchMerger.merge(
            tracks: rawTracks,
            query: query,
            preferRussian: filters.preferRussian
        )

        if filters.language == "ru" {
            mergedTracks = mergedTracks.filter(\.isRussian)
        }
        if let genreID = filters.genre, let option = GenreCatalog.option(for: genreID) {
            mergedTracks = mergedTracks.filter { track in
                let haystack = "\(track.genre ?? "") \(track.title) \(track.artist) \(track.album ?? "")"
                    .lowercased()
                return option.keywords.contains { haystack.contains($0.lowercased()) }
            }
        }
        if filters.onlyPlayable {
            mergedTracks = mergedTracks.filter { !$0.playableStreams.isEmpty }
        }

        tracks = mergedTracks
        albums = SearchMerger.mergeAlbums(rawAlbums)
        artists = SearchMerger.mergeArtists(rawArtists)
        issues = newIssues.sorted { $0.providerName < $1.providerName }
        stats = newStats.sorted { lhs, rhs in
            let lp = MusicSourceCatalog.info(for: lhs.id)?.priority ?? 0
            let rp = MusicSourceCatalog.info(for: rhs.id)?.priority ?? 0
            if lp != rp { return lp > rp }
            return lhs.name < rhs.name
        }
        isSearching = false
        lastCompletedAt = Date()
    }
}

// MARK: - Outcomes

private enum ProviderOutcome: Sendable {
    case success(providerID: String, name: String, result: SearchResult, milliseconds: Int)
    case failure(providerID: String, name: String, message: String)
    case cancelled(providerID: String, name: String)
}

// MARK: - Merge / dedup / ranking

enum SearchMerger {
    static func merge(
        tracks: [Track],
        query: String,
        preferRussian: Bool = true
    ) -> [Track] {
        guard !tracks.isEmpty else { return [] }

        var groups: [String: [Track]] = [:]
        for track in tracks {
            let key = dedupKey(for: track)
            groups[key, default: []].append(track)
        }

        var merged: [Track] = []
        merged.reserveCapacity(tracks.count)

        for group in groups.values {
            for cluster in clusterByDuration(group) {
                if let track = mergeCluster(cluster) {
                    merged.append(track)
                }
            }
        }

        return merged.sorted { lhs, rhs in
            let left = rankScore(lhs, query: query, preferRussian: preferRussian)
            let right = rankScore(rhs, query: query, preferRussian: preferRussian)
            if abs(left - right) > 0.001 { return left > right }
            let titleCompare = lhs.title.localizedStandardCompare(rhs.title)
            if titleCompare != .orderedSame { return titleCompare == .orderedAscending }
            return lhs.id < rhs.id
        }
    }

    static func mergeAlbums(_ albums: [Album]) -> [Album] {
        var seen = Set<String>()
        var result: [Album] = []
        for album in albums {
            let key = "\(RussianText.normalizedKey(album.artist))|\(RussianText.comparisonTitle(album.title))"
            guard key != "|", seen.insert(key).inserted else { continue }
            result.append(album)
        }
        return result.sorted { lhs, rhs in
            let lp = MusicSourceCatalog.info(for: lhs.providerID)?.priority ?? 0
            let rp = MusicSourceCatalog.info(for: rhs.providerID)?.priority ?? 0
            if lp != rp { return lp > rp }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }

    static func mergeArtists(_ artists: [Artist]) -> [Artist] {
        var seen = Set<String>()
        var result: [Artist] = []
        for artist in artists {
            let key = RussianText.normalizedKey(artist.name)
            guard key != "", seen.insert(key).inserted else { continue }
            result.append(artist)
        }
        return result.sorted { lhs, rhs in
            let lp = MusicSourceCatalog.info(for: lhs.providerID)?.priority ?? 0
            let rp = MusicSourceCatalog.info(for: rhs.providerID)?.priority ?? 0
            if lp != rp { return lp > rp }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    // MARK: - Dedup internals

    private static func dedupKey(for track: Track) -> String {
        let artist = RussianText.normalizedKey(track.artist)
        let title = RussianText.comparisonTitle(track.title)
        if artist.isEmpty && title.isEmpty {
            return "\(track.providerID)|\(track.id)"
        }
        return "\(artist)|\(title)"
    }

    private static func clusterByDuration(_ tracks: [Track]) -> [[Track]] {
        guard tracks.count > 1 else { return [tracks] }
        var remaining = tracks
        var clusters: [[Track]] = []

        while !remaining.isEmpty {
            let seed = remaining.removeFirst()
            var cluster = [seed]
            var index = 0
            while index < remaining.count {
                if compatibleDurations(seed.duration, remaining[index].duration) {
                    cluster.append(remaining.remove(at: index))
                } else {
                    index += 1
                }
            }
            clusters.append(cluster)
        }
        return clusters
    }

    private static func compatibleDurations(_ lhs: TimeInterval?, _ rhs: TimeInterval?) -> Bool {
        guard let lhs, let rhs, lhs > 0, rhs > 0 else {
            // Неизвестная длительность не должна склеивать явно разные версии,
            // но при отсутствии данных допускаем объединение.
            return lhs == nil || rhs == nil
        }
        return abs(lhs - rhs) <= 12
    }

    private static func mergeCluster(_ cluster: [Track]) -> Track? {
        guard !cluster.isEmpty else { return nil }
        let sorted = cluster.sorted { mergePreference($0) > mergePreference($1) }
        guard let primary = sorted.first else { return nil }

        var streams: [StreamSource] = []
        var seenURLs = Set<String>()
        for track in sorted {
            for stream in track.availableStreams {
                let key = stream.streamURL.absoluteString.lowercased()
                if seenURLs.insert(key).inserted {
                    streams.append(stream)
                }
            }
        }

        let bestArtwork = sorted.compactMap(\.artworkURL).first
        let bestDuration = sorted.compactMap(\.duration).first { $0 > 0 }
        let bestLicenseTrack = sorted.first { $0.license.isKnownOpenLicense }
        let bestGenre = sorted.compactMap(\.genre).first
        let bestLanguage = sorted.compactMap(\.language).first
        let isDownloadAllowed = sorted.contains { $0.isDownloadAllowed }
        let downloadURL = sorted.compactMap(\.downloadURL).first
        let sourcePageURL = sorted.compactMap(\.sourcePageURL).first
        let isStreamAllowed = sorted.contains { $0.isStreamAllowed }

        return Track(
            id: primary.id,
            title: primary.title,
            artist: primary.artist,
            album: primary.album,
            artworkURL: primary.artworkURL ?? bestArtwork,
            duration: primary.duration ?? bestDuration,
            providerID: primary.providerID,
            sourceID: primary.sourceID,
            isrc: sorted.compactMap(\.isrc).first,
            explicit: sorted.contains(where: \.explicit),
            availableStreams: streams,
            language: bestLanguage,
            originalTitle: primary.originalTitle,
            transliteratedTitle: primary.transliteratedTitle,
            license: bestLicenseTrack?.license ?? primary.license,
            licenseURL: bestLicenseTrack?.licenseURL ?? primary.licenseURL,
            attribution: primary.attribution ?? bestLicenseTrack?.attribution,
            isStreamAllowed: isStreamAllowed,
            isDownloadAllowed: isDownloadAllowed,
            downloadURL: downloadURL,
            sourcePageURL: sourcePageURL,
            region: primary.region,
            genre: primary.genre ?? bestGenre
        )
    }

    private static func mergePreference(_ track: Track) -> Double {
        let priority = MusicSourceCatalog.info(for: track.providerID)?.priority ?? 0
        var score = priority * 100
        if !track.playableStreams.isEmpty { score += 30 }
        if track.license.isKnownOpenLicense { score += 10 }
        if track.artworkURL != nil { score += 5 }
        if track.duration != nil { score += 2 }
        return score
    }

    static func rankScore(
        _ track: Track,
        query: String,
        preferRussian: Bool = true
    ) -> Double {
        let priority = MusicSourceCatalog.info(for: track.providerID)?.priority ?? 0
        var score = priority * 10

        if !track.playableStreams.isEmpty {
            score += 100
        } else {
            score -= 40
        }
        if track.license.isKnownOpenLicense { score += 5 }
        if track.artworkURL != nil { score += 3 }
        if track.duration != nil { score += 1 }

        let normalizedQuery = RussianText.normalizedKey(query)
        let title = RussianText.normalizedKey(track.title)
        let artist = RussianText.normalizedKey(track.artist)

        if !normalizedQuery.isEmpty {
            if title == normalizedQuery {
                score += 40
            } else if title.contains(normalizedQuery) {
                score += 20
            } else if normalizedQuery.contains(title) && title.count >= 3 {
                score += 14
            }
            if artist == normalizedQuery {
                score += 25
            } else if artist.contains(normalizedQuery) {
                score += 10
            }
        }

        if preferRussian {
            if track.isRussian { score += 6 }
            if LanguageDetector.isCyrillic(query) && track.isRussian { score += 35 }
        }

        return score
    }
}
