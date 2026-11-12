import Foundation

/// Реестр музыкальных провайдеров. Хранит actors и не выполняет сетевых
/// запросов сам по себе.
@MainActor
final class ProviderRegistry {
    private var providers: [String: any MusicProvider] = [:]

    init(providers: [any MusicProvider] = []) {
        for provider in providers {
            self.providers[provider.id] = provider
        }
    }

    func register(_ provider: any MusicProvider) {
        providers[provider.id] = provider
    }

    func unregister(providerID: String) {
        providers.removeValue(forKey: providerID)
    }

    func provider(for id: String) -> (any MusicProvider)? {
        providers[id]
    }

    var allProviders: [any MusicProvider] {
        providers.values.sorted { lhs, rhs in
            let leftPriority = MusicSourceCatalog.info(for: lhs.id)?.priority ?? 0
            let rightPriority = MusicSourceCatalog.info(for: rhs.id)?.priority ?? 0
            return leftPriority > rightPriority
        }
    }

    var searchableProviders: [any MusicProvider] {
        allProviders.filter { $0.capabilities.supportsSearch }
    }

    var providerCount: Int {
        providers.count
    }

    func isAvailable(providerID: String) -> Bool {
        guard let provider = providers[providerID] else { return false }
        return provider.capabilities.supportsSearch && !provider.capabilities.requiresAuthentication
    }
}
