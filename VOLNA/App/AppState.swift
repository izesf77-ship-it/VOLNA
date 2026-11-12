import SwiftUI
import Observation

/// Главное состояние приложения VOLNA
/// Содержит ссылки на все основные сервисы и общее состояние
@Observable
@MainActor
final class AppState {
    // Services
    private(set) var playerService: PlayerService
    private(set) var searchService: SearchService
    private(set) var libraryService: LibraryService
    private(set) var lyricsService: LyricsService
    private(set) var providerRegistry: ProviderRegistry
    
    // UI State
    var isPlayerPresented = false
    var selectedTab: AppTab = .home
    
    init() {
        // Initialize provider registry
        self.providerRegistry = ProviderRegistry()
        
        // Initialize services
        self.playerService = PlayerService()
        self.libraryService = LibraryService()
        self.lyricsService = LyricsService()
        self.searchService = SearchService(providerRegistry: providerRegistry)
        
        // Register providers
        Task {
            await registerProviders()
        }
    }
    
    private func registerProviders() async {
        // Register Jamendo provider
        let jamendoProvider = JamendoProvider()
        await providerRegistry.register(jamendoProvider)
        
        // Register Internet Archive provider
        let archiveProvider = InternetArchiveProvider()
        await providerRegistry.register(archiveProvider)
        
        // Register Wikimedia Commons provider
        let wikiProvider = WikimediaCommonsProvider()
        await providerRegistry.register(wikiProvider)
        
        print("✅ Registered \(await providerRegistry.providerCount) music providers")
    }
}

enum AppTab: String, CaseIterable {
    case home = "Главная"
    case search = "Поиск"
    case library = "Медиатека"
    case settings = "Настройки"
    
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .search: return "magnifyingglass"
        case .library: return "music.note.list"
        case .settings: return "gearshape.fill"
        }
    }
}
