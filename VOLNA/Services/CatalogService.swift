import Foundation
import Observation

struct CatalogSection: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let tracks: [Track]
}

struct CatalogSnapshot: Codable, Sendable {
    static let currentVersion = 2

    var version: Int = CatalogSnapshot.currentVersion
    var generatedAt: Date = .distantPast
    var sections: [CatalogSection] = []
    var tracks: [Track] = []
    var albums: [Album] = []
    var artists: [Artist] = []

    var russianTrackCount: Int {
        tracks.filter(\.isRussian).count
    }

    var isEmpty: Bool {
        tracks.isEmpty
    }
}

/// Редакционный каталог VOLNA.
///
/// Источник — публичный Jamendo API. Сервис загружает несколько реальных
/// выборок (новинки, популярное, русская музыка, жанры), проверяет каждый
/// трек по единым правилам, убирает дубли и сохраняет снимок в JSON внутри
/// Documents. Никаких придуманных исполнителей и треков здесь нет.
@MainActor
@Observable
final class CatalogService {
    private(set) var snapshot: CatalogSnapshot
    private(set) var isLoading = false
    private(set) var error: String?

    private let provider: JamendoProvider
    private let cacheURL: URL

    init(provider: JamendoProvider) {
        self.provider = provider
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.cacheURL = documents
            .appendingPathComponent("VOLNA", isDirectory: true)
            .appendingPathComponent("catalog.json")
        self.snapshot = Self.loadSnapshot(from: cacheURL) ?? CatalogSnapshot()
    }

    // MARK: - Public state

    var tracks: [Track] { snapshot.tracks }
    var albums: [Album] { snapshot.albums }
    var artists: [Artist] { snapshot.artists }
    var sections: [CatalogSection] { snapshot.sections }
    var russianTrackCount: Int { snapshot.russianTrackCount }
    var lastUpdated: Date? {
        snapshot.generatedAt == .distantPast ? nil : snapshot.generatedAt
    }

    var recentAlbums: [Album] {
        let calendar = Calendar(identifier: .gregorian)
        let currentYear = calendar.component(.year, from: Date())
        let cutoff = calendar.date(from: DateComponents(year: currentYear - 2, month: 1, day: 1))
            ?? .distantPast
        return albums.filter { ($0.releaseDate ?? .distantPast) >= cutoff }
    }

    var newReleaseTracks: [Track] {
        sections.first(where: { $0.id == "new" })?.tracks ?? []
    }

    var russianTracks: [Track] {
        sections.first(where: { $0.id == "russian" })?.tracks ?? []
    }

    var isEmpty: Bool { snapshot.isEmpty }

    var countsText: String {
        "\(tracks.count) треков · \(artists.count) исполнителей · \(albums.count) релизов"
    }

    // MARK: - Loading

    func loadIfNeeded() async {
        guard !isLoading else { return }
        if !snapshot.isEmpty, !isStale {
            return
        }
        await refresh(force: false)
    }

    func refresh(force: Bool) async {
        guard !isLoading else { return }
        if !force, !snapshot.isEmpty, !isStale {
            return
        }

        isLoading = true
        error = nil

        let queryResults = await fetchRawSections()
        guard !Task.isCancelled else {
            isLoading = false
            return
        }
        let built = buildSnapshot(from: queryResults)

        if built.tracks.isEmpty {
            if snapshot.isEmpty {
                error = "Не удалось получить каталог Jamendo. Проверьте соединение и повторите попытку."
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
        let tokens = CatalogQuality.normalized(query)
            .split(separator: " ")
            .map(String.init)
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
              !snapshot.tracks.isEmpty else {
            return nil
        }
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
            // Кэш не является критичным: при ошибке каталог продолжает работать
            // из памяти до следующего запуска.
        }
    }

    // MARK: - Queries

    private struct CatalogQuery: Sendable {
        let id: String
        let language: String?
        let tag: String?
        let search: String?
        let order: String
        let limit: Int
    }

    /// Реальные выборки публичного Jamendo API. Запросы намеренно разделены:
    /// русские новинки, популярное, жанровые теги и поиск по русскому рэпу,
    /// который не всегда отдаётся через тег. Ошибка одной выборки не ломает
    /// остальные.
    private func fetchRawSections() async -> [String: [Track]] {
        let queries: [CatalogQuery] = [
            CatalogQuery(id: "russian_popular", language: "ru", tag: nil, search: nil, order: "popularity_month", limit: 200),
            CatalogQuery(id: "russian_new", language: "ru", tag: nil, search: nil, order: "releasedate_desc", limit: 200),
            CatalogQuery(id: "global_popular", language: nil, tag: nil, search: nil, order: "popularity_month", limit: 100),
            CatalogQuery(id: "rap", language: "ru", tag: nil, search: "русский рэп", order: "popularity_month", limit: 80),
            CatalogQuery(id: "rock", language: "ru", tag: "rock", search: nil, order: "popularity_month", limit: 80),
            CatalogQuery(id: "pop", language: "ru", tag: "pop", search: nil, order: "popularity_month", limit: 80),
            CatalogQuery(id: "electronic", language: "ru", tag: "electronic", search: nil, order: "popularity_month", limit: 80),
            CatalogQuery(id: "indie", language: "ru", tag: "indie", search: nil, order: "popularity_month", limit: 80),
            CatalogQuery(id: "folk", language: "ru", tag: "folk", search: nil, order: "popularity_month", limit: 80),
            CatalogQuery(id: "classical", language: "ru", tag: "classical", search: nil, order: "popularity_month", limit: 80),
            CatalogQuery(id: "jazz", language: nil, tag: "jazz", search: nil, order: "popularity_month", limit: 80)
        ]

        var result: [String: [Track]] = [:]
        await withTaskGroup(of: (String, [Track]).self) { group in
            for query in queries {
                group.addTask { [provider] in
                    // Публичный Jamendo API периодически отвечает пустым списком
                    // на валидный запрос (наблюдалось на popularity_month,
                    // releasedate_desc и жанровых тегах). Пустой ответ не
                    // считается окончательным: делаем ещё две попытки, чтобы
                    // не терять целую полку из-за разового сбоя.
                    for attempt in 0..<3 {
                        if Task.isCancelled { return (query.id, []) }
                        if attempt > 0 {
                            try? await Task.sleep(nanoseconds: UInt64(attempt) * 400_000_000)
                        }
                        do {
                            let tracks = try await provider.discoveryTracks(
                                language: query.language,
                                tag: query.tag,
                                search: query.search,
                                order: query.order,
                                limit: query.limit
                            )
                            if !tracks.isEmpty {
                                return (query.id, tracks)
                            }
                        } catch {
                            if Task.isCancelled { return (query.id, []) }
                        }
                    }
                    return (query.id, [])
                }
            }
            for await (id, tracks) in group {
                result[id] = tracks
            }
        }
        return result
    }

    // MARK: - Snapshot building

    private func buildSnapshot(from raw: [String: [Track]]) -> CatalogSnapshot {
        let russian = unique(raw["russian_popular"].orEmpty + raw["russian_new"].orEmpty)
        // Jamendo периодически отдаёт пустой ответ на валидные запросы, а
        // «Новинки» должны быть русскоязычными. Поэтому полка строится из
        // реальной русской ленты releasedate_desc; дубли с «Русской волной»
        // отсекаются при сборке верхних полок.
        let newReleases = diversified(
            unique(raw["russian_new"].orEmpty)
                .sorted { ($0.releaseDate ?? .distantPast) > ($1.releaseDate ?? .distantPast) },
            maxPerArtist: 2
        )
        let popular = unique(raw["global_popular"].orEmpty + raw["russian_popular"].orEmpty)
        let rap = unique(raw["rap"].orEmpty)
        let rock = unique(raw["rock"].orEmpty)
        let pop = unique(raw["pop"].orEmpty)
        let electronic = unique(raw["electronic"].orEmpty)
        let indie = unique(raw["indie"].orEmpty)
        let folk = unique(raw["folk"].orEmpty)
        let jazz = unique(raw["jazz"].orEmpty)
        let classical = unique(raw["classical"].orEmpty)

        var sections: [CatalogSection] = []
        // Верхние редакционные полки не должны повторять друг друга: один и
        // тот же трек не показывается одновременно в герое, «Новинках» и
        // чарте. Жанровые полки ниже остаются независимыми, иначе из-за
        // пересечений они могли бы полностью опустеть.
        var topLevelKeys = Set<String>()

        func appendSection(
            id: String,
            title: String,
            subtitle: String,
            tracks: [Track],
            limit: Int,
            excluding: Set<String> = [],
            trackInTopLevel: Bool = false
        ) {
            var local = Set<String>()
            let picked = tracks.filter { track in
                guard CatalogQuality.isFeatured(track) else { return false }
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
            sections.append(
                CatalogSection(id: id, title: title, subtitle: subtitle, tracks: picked)
            )
        }

        appendSection(
            id: "russian",
            title: "Русская волна",
            subtitle: "Открытые релизы на русском языке",
            tracks: russian,
            limit: 36,
            trackInTopLevel: true
        )
        appendSection(
            id: "new",
            title: "Новинки",
            subtitle: "Свежие публикации в открытых каталогах",
            tracks: newReleases,
            limit: 30,
            excluding: topLevelKeys,
            trackInTopLevel: true
        )
        appendSection(
            id: "popular",
            title: "Популярное сейчас",
            subtitle: "Что чаще слушают в открытом каталоге",
            tracks: popular,
            limit: 30,
            excluding: topLevelKeys,
            trackInTopLevel: true
        )
        appendSection(
            id: "rap",
            title: "Русский рэп",
            subtitle: "Новые имена и независимые релизы",
            tracks: rap,
            limit: 24
        )
        appendSection(
            id: "rock",
            title: "Рок и альтернатива",
            subtitle: "Гитары, которое стоит включить",
            tracks: rock,
            limit: 24
        )
        appendSection(
            id: "pop",
            title: "Поп",
            subtitle: "Мелодии с характером",
            tracks: pop,
            limit: 24
        )
        appendSection(
            id: "electronic",
            title: "Электроника",
            subtitle: "Синтез, ритм и пространство",
            tracks: electronic,
            limit: 24
        )
        appendSection(
            id: "indie",
            title: "Инди",
            subtitle: "Самостоятельная музыка без посредников",
            tracks: indie,
            limit: 24
        )
        appendSection(
            id: "folk",
            title: "Фолк и акустика",
            subtitle: "Живые голоса и инструменты",
            tracks: folk,
            limit: 20
        )
        appendSection(
            id: "jazz",
            title: "Джаз и инструментал",
            subtitle: "Для спокойного вечера",
            tracks: jazz,
            limit: 20
        )
        appendSection(
            id: "classical",
            title: "Классика",
            subtitle: "Свободные записи академической музыки",
            tracks: classical,
            limit: 20
        )

        // Каталог целиком дедуплицируется отдельно. Полки могут пересекаться:
        // один и тот же релиз законно встречается в «Русской волне» и в жанровой
        // подборке, но внутри полки дублей нет.
        let allTracks = unique(raw.values.flatMap { $0 })
            .filter(CatalogQuality.isFeatured)
            .sorted {
                let left = CatalogQuality.score($0)
                let right = CatalogQuality.score($1)
                if abs(left - right) > 0.001 { return left > right }
                return $0.id < $1.id
            }

        let albums = makeAlbums(from: allTracks)
        let artists = makeArtists(from: allTracks)
        let orderedSections = sections.filter { !$0.tracks.isEmpty }

        return CatalogSnapshot(
            generatedAt: Date(),
            sections: orderedSections,
            tracks: allTracks,
            albums: albums,
            artists: artists
        )
    }

    private func unique(_ tracks: [Track]) -> [Track] {
        var seen = Set<String>()
        var result: [Track] = []
        for track in tracks {
            let key = CatalogQuality.dedupKey(for: track)
            if seen.insert(key).inserted {
                result.append(track)
            }
        }
        return result
    }

    /// Не даёт одной новой пластинке занять всю полку «Новинки»: у каждого
    /// исполнителя остаётся не больше `maxPerArtist` треков.
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
        struct AlbumGroup {
            var tracks: [Track]
            var best: Track
        }

        var groups: [String: AlbumGroup] = [:]
        for track in tracks {
            guard let title = track.album, !title.isEmpty, track.artworkURL != nil else { continue }
            let key = CatalogQuality.albumKey(artist: track.artist, title: title)
            if var group = groups[key] {
                group.tracks.append(track)
                if CatalogQuality.score(track) > CatalogQuality.score(group.best) {
                    group.best = track
                }
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
                id: best.albumID ?? "\(best.providerID)_album_\(title.stableFNVHash)",
                title: title,
                artist: best.artist,
                artworkURL: best.artworkURL,
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
                    id: "jamendo_artist_\(key.stableFNVHash)",
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
                    artworkURL: pair.1.artworkURL,
                    biography: pair.0.biography,
                    providerID: pair.0.providerID
                )
            }
            .sorted { lhs, rhs in
                lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }
}

private extension Optional where Wrapped == [Track] {
    var orEmpty: [Track] { self ?? [] }
}
