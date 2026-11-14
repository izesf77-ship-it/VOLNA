import Foundation
import Observation

struct CatalogSection: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let tracks: [Track]
}

struct CatalogSnapshot: Codable, Sendable {
    static let currentVersion = 3

    var version: Int = CatalogSnapshot.currentVersion
    var generatedAt: Date = .distantPast
    var sections: [CatalogSection] = []
    var tracks: [Track] = []
    var albums: [Album] = []
    var artists: [Artist] = []

    var russianTrackCount: Int { tracks.filter(\.isRussian).count }
    var isEmpty: Bool { tracks.isEmpty }
}

/// Multi-source catalog service.
/// Aggregates discovery from enabled providers, filters/merges tracks, builds
/// editorial sections and caches the snapshot in Documents/VOLNA/catalog.json.
@MainActor
@Observable
final class CatalogService {
    private(set) var snapshot: CatalogSnapshot
    private(set) var isLoading = false
    private(set) var error: String?

    private let providers: [any MusicProvider]
    private let enabledProviderIDs: () -> Set<String>
    private let cacheURL: URL

    init(providers: [any MusicProvider], enabledProviderIDs: @escaping () -> Set<String>) {
        self.providers = providers
        self.enabledProviderIDs = enabledProviderIDs
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.cacheURL = documents
            .appendingPathComponent("VOLNA", isDirectory: true)
            .appendingPathComponent("catalog.json")
        self.snapshot = Self.loadSnapshot(from: cacheURL) ?? CatalogSnapshot()
    }

    // Convenience for existing call sites/tests that may pass Jamendo directly.
    convenience init(provider: JamendoProvider) {
        self.init(providers: [provider], enabledProviderIDs: { ["jamendo"] })
    }

    // MARK: - Public state

    var tracks: [Track] { snapshot.tracks }
    var albums: [Album] { snapshot.albums }
    var artists: [Artist] { snapshot.artists }
    var sections: [CatalogSection] { snapshot.sections }
    var russianTrackCount: Int { snapshot.russianTrackCount }
    var lastUpdated: Date? { snapshot.generatedAt == .distantPast ? nil : snapshot.generatedAt }

    var recentAlbums: [Album] {
        let calendar = Calendar(identifier: .gregorian)
        let currentYear = calendar.component(.year, from: Date())
        let cutoff = calendar.date(from: DateComponents(year: currentYear - 2, month: 1, day: 1)) ?? .distantPast
        return albums.filter { ($0.releaseDate ?? .distantPast) >= cutoff }
    }

    var newReleaseTracks: [Track] { sections.first(where: { $0.id == "new" })?.tracks ?? [] }
    var russianTracks: [Track] { sections.first(where: { $0.id == "russian" })?.tracks ?? [] }
    var isEmpty: Bool { snapshot.isEmpty }
    var countsText: String { "\(tracks.count) треков · \(artists.count) исполнителей · \(albums.count) релизов" }

    // MARK: - Loading

    func loadIfNeeded() async {
        guard !isLoading else { return }
        if !snapshot.isEmpty, !isStale { return }
        await refresh(force: false)
    }

    func refresh(force: Bool) async {
        guard !isLoading else { return }
        if !force, !snapshot.isEmpty, !isStale { return }

        isLoading = true
        error = nil

        let discovered = await fetchDiscovery()
        guard !Task.isCancelled else { isLoading = false; return }
        let built = buildSnapshot(from: discovered)

        if built.tracks.isEmpty {
            if snapshot.isEmpty {
                error = "Не удалось получить каталог из доступных источников. Проверьте соединение и настройки источников."
            } else {
                error = "Не удалось обновить каталог. Показаны сохранённые релизы."
            }
        } else {
            snapshot = built
            saveSnapshot(built)
        }

        isLoading = false
    }

    func searchLocal(_ query: String, limit: Int = 40) -> [Track] {
        let tokens = CatalogQuality.normalized(query).split(separator: " ").map(String.init)
        guard !tokens.isEmpty else { return [] }
        return tracks
            .filter { track in
                let haystack = CatalogQuality.normalized(track.searchableText)
                return tokens.allSatisfy { haystack.contains($0) }
            }
            .sorted {
                let left = CatalogQuality.score($0)
                let right = CatalogQuality.score($1)
                if abs(left - right) > 0.001 { return left > right }
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Cache

    private var isStale: Bool {
        guard let date = lastUpdated else { return true }
        return Date().timeIntervalSince(date) > 12 * 60 * 60
    }

    private static func loadSnapshot(from url: URL) -> CatalogSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let snapshot = try? decoder.decode(CatalogSnapshot.self, from: data),
              snapshot.version == CatalogSnapshot.currentVersion,
              !snapshot.tracks.isEmpty else { return nil }
        return snapshot
    }

    private func saveSnapshot(_ snapshot: CatalogSnapshot) {
        let directory = cacheURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.withoutEscapingSlashes]
            let data = try encoder.encode(snapshot)
            try data.write(to: cacheURL, options: .atomic)
        } catch {
            // Cache is non-critical.
        }
    }

    // MARK: - Discovery

    private enum DiscoveryBucket: String, CaseIterable {
        case russian, international, new, popular, rap, pop, rock, electronic, indie
    }

    private func fetchDiscovery() async -> [DiscoveryBucket: [Track]] {
        let enabled = enabledProviderIDs()
        let active = providers.filter { enabled.contains($0.id) || $0.capabilities.isLocal }
        guard !active.isEmpty else { return [:] }

        let queries: [(DiscoveryBucket, String, SearchType)] = [
            (.russian, "русская музыка", .track),
            (.russian, "русский рэп", .track),
            (.international, "popular music", .track),
            (.international, "international hits", .track),
            (.new, "new releases", .track),
            (.popular, "popular", .track),
            (.rap, "hip hop rap", .track),
            (.pop, "pop music", .track),
            (.rock, "rock", .track),
            (.electronic, "electronic", .track),
            (.indie, "indie", .track)
        ]

        var buckets: [DiscoveryBucket: [Track]] = [:]
        // Limit concurrency to avoid hammering public APIs.
        let maxConcurrent = 4
        var index = 0
        while index < queries.count {
            let chunk = Array(queries[index..<min(index + maxConcurrent, queries.count)])
            let chunkResults = await withTaskGroup(of: (DiscoveryBucket, [Track]).self) { group in
                for item in chunk {
                    group.addTask { [active] in
                        let tracks = await self.fetchBucketTracks(bucket: item.0, query: item.1, type: item.2, providers: active)
                        return (item.0, tracks)
                    }
                }
                var out: [(DiscoveryBucket, [Track])] = []
                for await r in group { out.append(r) }
                return out
            }
            for (bucket, tracks) in chunkResults {
                buckets[bucket, default: []].append(contentsOf: tracks)
            }
            index += maxConcurrent
        }

        // Extra high-quality discovery for providers with native endpoints.
        for provider in active {
            if let jamendo = provider as? JamendoProvider {
                async let ruPop = (try? jamendo.discoveryTracks(language: "ru", order: "popularity_month", limit: 120)) ?? []
                async let ruNew = (try? jamendo.discoveryTracks(language: "ru", order: "releasedate_desc", limit: 120)) ?? []
                async let global = (try? jamendo.discoveryTracks(language: nil, order: "popularity_month", limit: 80)) ?? []
                let (a,b,c) = await (ruPop, ruNew, global)
                buckets[.russian, default: []].append(contentsOf: a)
                buckets[.new, default: []].append(contentsOf: b)
                buckets[.popular, default: []].append(contentsOf: c)
                buckets[.international, default: []].append(contentsOf: c)
            } else if let audius = provider as? AudiusProvider {
                async let trending = (try? audius.trendingTracks(limit: 60, time: "week")) ?? []
                async let monthly = (try? audius.latestTracks(limit: 40)) ?? []
                let (t, m) = await (trending, monthly)
                buckets[.popular, default: []].append(contentsOf: t)
                buckets[.international, default: []].append(contentsOf: t)
                buckets[.new, default: []].append(contentsOf: m)
            }
        }

        return buckets
    }

    private func fetchBucketTracks(
        bucket: DiscoveryBucket,
        query: String,
        type: SearchType,
        providers: [any MusicProvider]
    ) async -> [Track] {
        await withTaskGroup(of: [Track].self) { group in
            for provider in providers {
                guard provider.capabilities.supportsSearch else { continue }
                group.addTask {
                    if Task.isCancelled { return [] }
                    do {
                        let result = try await provider.search(query: query, type: type)
                        return result.tracks
                    } catch {
                        return []
                    }
                }
            }
            var all: [Track] = []
            for await part in group { all.append(contentsOf: part) }
            // Keep better candidates per bucket.
            return Array(all.prefix(200))
        }
    }

    // MARK: - Snapshot building

    private func buildSnapshot(from raw: [DiscoveryBucket: [Track]]) -> CatalogSnapshot {
        let russian = merged(raw[.russian].orEmpty, preferRussian: true)
        let international = merged(raw[.international].orEmpty, preferRussian: false)
        let popular = merged((raw[.popular].orEmpty) + (raw[.international].orEmpty), preferRussian: true)
        let new = merged((raw[.new].orEmpty) + (raw[.russian].orEmpty.filter { $0.releaseDate != nil }), preferRussian: true)
            .sorted { ($0.releaseDate ?? .distantPast) > ($1.releaseDate ?? .distantPast) }
        let rap = merged(raw[.rap].orEmpty, preferRussian: true)
        let pop = merged(raw[.pop].orEmpty, preferRussian: true)
        let rock = merged(raw[.rock].orEmpty, preferRussian: true)
        let electronic = merged(raw[.electronic].orEmpty, preferRussian: true)
        let indie = merged(raw[.indie].orEmpty, preferRussian: true)

        var sections: [CatalogSection] = []
        var topLevelKeys = Set<String>()

        func appendSection(
            id: String,
            title: String,
            subtitle: String,
            tracks: [Track],
            limit: Int,
            excluding: Set<String> = [],
            trackInTopLevel: Bool = false,
            featuredOnly: Bool = true
        ) {
            var local = Set<String>()
            let picked = tracks.filter { track in
                let qualifies = featuredOnly
                    ? CatalogQuality.isFeatured(track)
                    : CatalogQuality.isDisplayable(track)
                guard qualifies else { return false }
                let key = CatalogQuality.dedupKey(for: track)
                guard local.insert(key).inserted, !excluding.contains(key) else { return false }
                return true
            }
            .prefix(limit)
            .map { $0 }

            guard !picked.isEmpty else { return }
            if trackInTopLevel {
                topLevelKeys.formUnion(picked.map { CatalogQuality.dedupKey(for: $0) })
            }
            sections.append(CatalogSection(id: id, title: title, subtitle: subtitle, tracks: picked))
        }

        appendSection(id: "russian", title: "Русская волна", subtitle: "Русская музыка из доступных открытых источников", tracks: russian.filter(\.isRussian), limit: 36, trackInTopLevel: true)
        appendSection(id: "international", title: "Зарубежная музыка", subtitle: "Международные треки из открытых каталогов", tracks: international.filter { !$0.isRussian }, limit: 30, excluding: topLevelKeys, trackInTopLevel: true)
        appendSection(id: "new", title: "Новинки", subtitle: "Свежие и актуальные релизы", tracks: diversified(new, maxPerArtist: 2), limit: 30, excluding: topLevelKeys, trackInTopLevel: true)
        appendSection(id: "popular", title: "Популярное", subtitle: "Популярные композиции из подключённых источников", tracks: popular, limit: 30, excluding: topLevelKeys, trackInTopLevel: true)
        appendSection(id: "rap", title: "Рэп и хип-хоп", subtitle: "Ритм, поток и энергия", tracks: rap, limit: 24)
        appendSection(id: "pop", title: "Поп", subtitle: "Мелодии для любого настроения", tracks: pop, limit: 24)
        appendSection(id: "rock", title: "Рок", subtitle: "Гитары и драйв", tracks: rock, limit: 24)
        appendSection(id: "electronic", title: "Электроника", subtitle: "Синтез, ритм и пространство", tracks: electronic, limit: 24)
        appendSection(id: "indie", title: "Инди", subtitle: "Независимая музыка", tracks: indie, limit: 24)

        let allTracks = merged(raw.values.flatMap { $0 }, preferRussian: true)
            .filter { CatalogQuality.isDisplayable($0) }
            .sorted {
                let left = CatalogQuality.score($0)
                let right = CatalogQuality.score($1)
                if abs(left - right) > 0.001 { return left > right }
                return $0.id < $1.id
            }

        let albums = makeAlbums(from: allTracks.filter { $0.album != nil })
        let artists = makeArtists(from: allTracks)

        // Album/artist sections as track-backed editorial rows for navigation context.
        let albumRepresentative = uniqueTracks(Array(albums.prefix(24).compactMap { $0.tracks.first }))
        if !albumRepresentative.isEmpty {
            sections.append(CatalogSection(id: "albums", title: "Альбомы", subtitle: "Подборка релизов из каталога", tracks: albumRepresentative))
        }
        let artistRepresentative = uniqueTracks(Array(artists.prefix(24).compactMap { artist in allTracks.first(where: { CatalogQuality.artistKey($0.artist) == CatalogQuality.artistKey(artist.name) }) }))
        if !artistRepresentative.isEmpty {
            sections.append(CatalogSection(id: "artists", title: "Исполнители", subtitle: "Представительные треки исполнителей", tracks: artistRepresentative))
        }

        return CatalogSnapshot(
            generatedAt: Date(),
            sections: sections.filter { !$0.tracks.isEmpty },
            tracks: allTracks,
            albums: albums,
            artists: artists
        )
    }

    private func merged(_ tracks: [Track], preferRussian: Bool) -> [Track] {
        SearchMerger.merge(tracks: tracks, query: "", preferRussian: preferRussian)
            .filter { CatalogQuality.isDisplayable($0) }
    }

    private func uniqueTracks(_ tracks: [Track]) -> [Track] {
        var seen = Set<String>()
        var result: [Track] = []
        for track in tracks {
            let key = CatalogQuality.dedupKey(for: track)
            if seen.insert(key).inserted { result.append(track) }
        }
        return result
    }

    private func diversified(_ tracks: [Track], maxPerArtist: Int) -> [Track] {
        guard maxPerArtist > 0 else { return tracks }
        var counts: [String: Int] = [:]
        return tracks.filter { track in
            let key = CatalogQuality.artistKey(track.artist)
            let count = counts[key, default: 0]
            guard count < maxPerArtist else { return false }
            counts[key] = count + 1
            return true
        }
    }

    private func makeAlbums(from tracks: [Track]) -> [Album] {
        struct AlbumGroup { var tracks: [Track]; var best: Track }
        var groups: [String: AlbumGroup] = [:]
        for track in tracks {
            guard let title = track.album, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            let key = CatalogQuality.albumKey(artist: track.artist, title: title)
            if var group = groups[key] {
                group.tracks.append(track)
                if CatalogQuality.score(track) > CatalogQuality.score(group.best) { group.best = track }
                groups[key] = group
            } else {
                groups[key] = AlbumGroup(tracks: [track], best: track)
            }
        }
        return groups.values.compactMap { group -> Album? in
            let best = group.best
            guard let title = best.album, !title.isEmpty else { return nil }
            let sortedTracks = group.tracks.sorted { lhs, rhs in
                let left = lhs.trackNumber ?? Int.max
                let right = rhs.trackNumber ?? Int.max
                if left != right { return left < right }
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
            return Album(
                id: best.albumID ?? "\(best.providerID)_album_\(CatalogQuality.albumKey(artist: best.artist, title: title).stableFNVHash)",
                title: title,
                artist: best.artist,
                artworkURL: best.artworkURL ?? sortedTracks.compactMap(\.artworkURL).first,
                releaseDate: group.tracks.compactMap(\.releaseDate).max(),
                providerID: best.providerID,
                tracks: sortedTracks
            )
        }
        .sorted { lhs, rhs in
            let left = lhs.releaseDate ?? .distantPast
            let right = rhs.releaseDate ?? .distantPast
            if left != right { return left > right }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }

    private func makeArtists(from tracks: [Track]) -> [Artist] {
        var artistsByKey: [String: (Artist, Track)] = [:]
        for track in tracks {
            let key = CatalogQuality.artistKey(track.artist)
            guard !key.isEmpty, !CatalogQuality.isUnknownArtist(track.artist) else { continue }
            if let existing = artistsByKey[key] {
                if CatalogQuality.score(track) > CatalogQuality.score(existing.1) {
                    artistsByKey[key] = (existing.0, track)
                }
            } else {
                let artist = Artist(
                    id: "\(track.providerID)_artist_\(key.stableFNVHash)",
                    name: track.artist,
                    artworkURL: track.artworkURL,
                    biography: nil,
                    providerID: track.providerID
                )
                artistsByKey[key] = (artist, track)
            }
        }
        return artistsByKey.values
            .map { pair in
                Artist(
                    id: pair.0.id,
                    name: pair.0.name,
                    artworkURL: pair.1.artworkURL ?? pair.0.artworkURL,
                    biography: pair.0.biography,
                    providerID: pair.0.providerID
                )
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

private extension Optional where Wrapped == [Track] {
    var orEmpty: [Track] { self ?? [] }
}
