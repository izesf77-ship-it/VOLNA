import Foundation

/// Реестр музыкальных провайдеров
@MainActor
final class ProviderRegistry: Sendable {
    private var providers: [String: any MusicProvider] = [:]
    
    init() {}
    
    /// Зарегистрировать провайдера
    func register(_ provider: any MusicProvider) async {
        let id = await provider.id
        providers[id] = provider
        print("📝 Registered provider: \(await provider.name)")
    }
    
    /// Удалить провайдера
    func unregister(providerID: String) {
        providers.removeValue(forKey: providerID)
        print("🗑️ Unregistered provider: \(providerID)")
    }
    
    /// Получить провайдера по ID
    func provider(for id: String) -> (any MusicProvider)? {
        providers[id]
    }
    
    /// Все зарегистрированные провайдеры
    var allProviders: [any MusicProvider] {
        Array(providers.values)
    }
    
    /// Провайдеры с возможностью поиска
    var searchableProviders: [any MusicProvider] {
        allProviders.filter { provider in
            Task { await provider.capabilities.supportsSearch }
            return true
        }
    }
    
    /// Количество провайдеров
    var providerCount: Int {
        providers.count
    }
    
    /// Проверить доступность провайдера
    func isAvailable(providerID: String) async -> Bool {
        guard let provider = provider(for: providerID) else {
            return false
        }
        
        let capabilities = await provider.capabilities
        if capabilities.requiresAuthentication {
            // TODO: Check authentication status
            return false
        }
        
        return true
    }
}
