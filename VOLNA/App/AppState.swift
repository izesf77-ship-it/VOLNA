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
    let searchHistory: SearchHistoryStore
    let catalog: CatalogService

    // UI state
    var selectedTab: AppTab = .home
    var isPlayerPresented = false
    /// Измеренная высота плавающих нижних контролов (мини-плеер + таб-бар).
    /// Используется для safe-area inset контента без магических констант.
    var bottomControlsHeight: CGFloat = 0

    /// Единая точка презентации настроек (используется всеми тремя вкладками).
    var showSettings = false

    /// Токен для debug-скриншота «Главная с прокруткой».
    var screenshotScrollToken = 0

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
        let jamendo = JamendoProvider()
        let audius = AudiusProvider()
        let internetArchive = InternetArchiveProvider()
        let wikimedia = WikimediaCommonsProvider()
        let openverse = OpenverseProvider()
        let registry = ProviderRegistry(providers: [
            jamendo,
            audius,
            internetArchive,
            wikimedia,
            openverse,
            directProvider
        ])
        let catalog = CatalogService(
            providers: registry.allProviders,
            enabledProviderIDs: { settings.enabledProviderIDs }
        )

        self.settings = settings
        self.library = library
        self.player = player
        self.lyricsService = lyrics
        self.directLinkStore = directStore
        self.directProvider = directProvider
        self.providerRegistry = registry
        self.searchService = SearchService(providerRegistry: registry)
        self.searchHistory = SearchHistoryStore()
        self.catalog = catalog
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

        if force {
            await catalog.refresh(force: true)
        } else {
            await catalog.loadIfNeeded()
        }

        homeSections = catalog.sections.map { section in
            HomeSection(
                id: section.id,
                title: section.title,
                subtitle: section.subtitle,
                tracks: section.tracks,
                colors: colors(for: section.id)
            )
        }

        if homeSections.isEmpty {
            homeError = catalog.error
                ?? "Каталог пока пуст. Проверьте соединение и повторите попытку."
        }
        isHomeLoading = false
    }

    func refreshCatalog() async {
        await catalog.refresh(force: true)
        homeSections = catalog.sections.map { section in
            HomeSection(
                id: section.id,
                title: section.title,
                subtitle: section.subtitle,
                tracks: section.tracks,
                colors: colors(for: section.id)
            )
        }
        homeError = homeSections.isEmpty ? catalog.error : nil
    }

    private func colors(for sectionID: String) -> [Color] {
        switch sectionID {
        case "russian": return [Color(hex: "7B61FF"), Color(hex: "FF5C9D")]
        case "new": return [Color(hex: "4C9BFF"), Color(hex: "5FE7FF")]
        case "popular": return [Color(hex: "7B61FF"), Color(hex: "4C9BFF")]
        case "rap": return [Color(hex: "FF7A3D"), Color(hex: "FF5C9D")]
        case "rock": return [Color(hex: "FF5F5F"), Color(hex: "FFB63B")]
        case "pop": return [Color(hex: "FF5C9D"), Color(hex: "7B61FF")]
        case "electronic": return [Color(hex: "32E6A0"), Color(hex: "4C9BFF")]
        case "indie": return [Color(hex: "4C9BFF"), Color(hex: "7B61FF")]
        case "folk": return [Color(hex: "FFB63B"), Color(hex: "32E6A0")]
        case "jazz": return [Color(hex: "FFB63B"), Color(hex: "FF7A3D")]
        case "classical": return [Color(hex: "FFB63B"), Color(hex: "FF5F5F")]
        default: return [Color(hex: "7B61FF"), Color(hex: "4C9BFF")]
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

    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var buildSHA: String {
        Bundle.main.infoDictionary?["CFBundleBuildSHA"] as? String ?? "local"
    }

    var shortBuildSHA: String {
        String(buildSHA.prefix(7))
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

    var title: String {
        switch self {
        case .home: return "Главная"
        case .search: return "Поиск"
        case .library: return "Медиатека"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house"
        case .search: return "magnifyingglass"
        case .library: return "square.stack"
        }
    }

    var selectedIcon: String {
        switch self {
        case .home: return "house.fill"
        case .search: return "magnifyingglass"
        case .library: return "square.stack.fill"
        }
    }
}
