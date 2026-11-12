import SwiftUI
import Observation

/// Главное состояние приложения. Сервисы создаются один раз и живут всё время
/// работы приложения. Провайдеры регистрируются синхронно, без гонок при старте.
@MainActor
@Observable
final class AppState {
    let settings: SettingsStore
    let library: LibraryService
    let player: PlayerService
    let lyricsService: LyricsService
    let directLinkStore: DirectLinkStore
    let directProvider: DirectMusicProvider
    let providerRegistry: ProviderRegistry
    let searchService: SearchService

    // UI state
    var selectedTab: AppTab = .home
    var isPlayerPresented = false

    // Home feed
    private(set) var homeSections: [HomeSection] = []
    private(set) var isHomeLoading = false
    private(set) var homeError: String?

    init() {
        let settings = SettingsStore()
        let library = LibraryService()
        let player = PlayerService()
        let lyrics = LyricsService()
        let directStore = DirectLinkStore()
        let directProvider = DirectMusicProvider(links: directStore.links)
        let registry = ProviderRegistry(providers: [
            JamendoProvider(),
            InternetArchiveProvider(),
            WikimediaCommonsProvider(),
            OpenverseProvider(),
            directProvider
        ])

        self.settings = settings
        self.library = library
        self.player = player
        self.lyricsService = lyrics
        self.directLinkStore = directStore
        self.directProvider = directProvider
        self.providerRegistry = registry
        self.searchService = SearchService(providerRegistry: registry)
    }

    // MARK: - Playback helpers

    func play(_ track: Track, in tracks: [Track]? = nil) {
        player.play(track, queue: tracks)
        library.recordPlayed(track)
    }

    func toggleFavorite(_ track: Track) -> Bool {
        library.toggleFavorite(track)
    }

    func showPlayer() {
        if player.currentTrack != nil {
            isPlayerPresented = true
        }
    }

    // MARK: - Search helper

    func performSearch(
        query: String,
        type: SearchType = .all,
        filters: SearchFilters
    ) {
        var effectiveFilters = filters
        effectiveFilters.preferRussian = settings.preferRussianMusic
        searchService.search(
            query: query,
            type: type,
            filters: effectiveFilters,
            enabledProviderIDs: settings.enabledProviderIDs
        )
    }

    // MARK: - Home feed

    func loadHome(force: Bool = false) async {
        guard !isHomeLoading else { return }
        if !force, !homeSections.isEmpty { return }

        isHomeLoading = true
        homeError = nil

        async let russian = providerTracks(
            providerID: "jamendo",
            query: "русский рок",
            limit: 20
        )
        async let russianAlternative = providerTracks(
            providerID: "internet_archive",
            query: "русский рок",
            limit: 12
        )
        async let russianIndie = providerTracks(
            providerID: "jamendo",
            query: "russian indie",
            limit: 16
        )
        async let folk = providerTracks(
            providerID: "internet_archive",
            query: "russian folk",
            limit: 12
        )
        async let classical = providerTracks(
            providerID: "wikimedia_commons",
            query: "russian classical",
            limit: 12
        )
        async let freeScene = providerTracks(
            providerID: "jamendo",
            query: "indie",
            limit: 16
        )

        let results = await (russian, russianAlternative, russianIndie, folk, classical, freeScene)
        let russianCombined = SearchMerger.merge(
            tracks: results.0 + results.1 + results.2,
            query: "русский рок"
        ).filter { $0.isRussian && !$0.playableStreams.isEmpty }

        var sections: [HomeSection] = []
        if !russianCombined.isEmpty {
            sections.append(
                HomeSection(
                    id: "russian",
                    title: "Русская волна",
                    subtitle: "Открытые записи на русском языке",
                    tracks: Array(russianCombined.prefix(14)),
                    colors: [Color(hex: "7C5CFF"), Color(hex: "FF5CA8")]
                )
            )
        }
        if !results.3.isEmpty {
            sections.append(
                HomeSection(
                    id: "archive",
                    title: "Архивы и фольклор",
                    subtitle: "Internet Archive: только элементы с открытой лицензией",
                    tracks: Array(results.3.prefix(12)),
                    colors: [Color(hex: "3AA0FF"), Color(hex: "6EE7F9")]
                )
            )
        }
        if !results.4.isEmpty {
            sections.append(
                HomeSection(
                    id: "classical",
                    title: "Классика и общественное достояние",
                    subtitle: "Wikimedia Commons: свободные аудиозаписи",
                    tracks: Array(results.4.prefix(12)),
                    colors: [Color(hex: "F5B84B"), Color(hex: "FF7A59")]
                )
            )
        }
        if !results.5.isEmpty {
            sections.append(
                HomeSection(
                    id: "indie",
                    title: "Свободная сцена",
                    subtitle: "Независимые исполнители Jamendo",
                    tracks: Array(results.5.prefix(14)),
                    colors: [Color(hex: "27D796"), Color(hex: "3AA0FF")]
                )
            )
        }

        homeSections = sections
        if sections.isEmpty {
            homeError = "Не удалось загрузить подборки. Проверьте соединение и включённые источники."
        }
        isHomeLoading = false
    }

    private func providerTracks(
        providerID: String,
        query: String,
        limit: Int
    ) async -> [Track] {
        guard settings.isProviderEnabled(providerID),
              let provider = providerRegistry.provider(for: providerID) else {
            return []
        }
        do {
            let result = try await provider.search(query: query, type: .track)
            return Array(
                result.tracks
                    .filter { !$0.playableStreams.isEmpty }
                    .prefix(limit)
            )
        } catch {
            return []
        }
    }

    // MARK: - Direct links

    @discardableResult
    func addDirectLink(
        title: String,
        artist: String,
        url: String,
        license: LicenseType,
        licenseURL: URL?
    ) async -> DirectLink? {
        let link = await directLinkStore.add(
            title: title,
            artist: artist,
            urlString: url,
            license: license,
            licenseURL: licenseURL
        )
        if link != nil {
            await directProvider.updateLinks(directLinkStore.links)
        }
        return link
    }

    func removeDirectLink(id: String) async {
        directLinkStore.remove(id: id)
        await directProvider.updateLinks(directLinkStore.links)
    }

    func removeAllDirectLinks() async {
        directLinkStore.removeAll()
        await directProvider.updateLinks(directLinkStore.links)
    }

    // MARK: - Sources health

    func checkAllProviders() async -> [String: ProviderHealth] {
        let providers = providerRegistry.allProviders
        return await withTaskGroup(
            of: (String, ProviderHealth).self,
            returning: [String: ProviderHealth].self
        ) { group in
            for provider in providers {
                group.addTask {
                    let health = await provider.healthCheck()
                    return (provider.id, health)
                }
            }
            var result: [String: ProviderHealth] = [:]
            for await (id, health) in group {
                result[id] = health
            }
            return result
        }
    }

    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

struct HomeSection: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let tracks: [Track]
    let colors: [Color]
}

enum AppTab: String, CaseIterable, Hashable {
    case home
    case search
    case library
    case settings

    var title: String {
        switch self {
        case .home: return "Главная"
        case .search: return "Поиск"
        case .library: return "Медиатека"
        case .settings: return "Настройки"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house"
        case .search: return "magnifyingglass"
        case .library: return "square.stack"
        case .settings: return "gearshape"
        }
    }

    var selectedIcon: String {
        switch self {
        case .home: return "house.fill"
        case .search: return "magnifyingglass"
        case .library: return "square.stack.fill"
        case .settings: return "gearshape.fill"
        }
    }
}
