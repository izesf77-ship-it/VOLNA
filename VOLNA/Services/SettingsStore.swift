import Foundation
import Observation

/// Настройки приложения. Хранятся только в UserDefaults на устройстве.
@MainActor
@Observable
final class SettingsStore {
    var enabledProviderIDs: Set<String> {
        didSet { saveProviders() }
    }

    var preferRussianMusic: Bool {
        didSet { defaults.set(preferRussianMusic, forKey: Keys.preferRussian) }
    }

    var showExplicitContent: Bool {
        didSet { defaults.set(showExplicitContent, forKey: Keys.showExplicit) }
    }

    var showLicenseBadges: Bool {
        didSet { defaults.set(showLicenseBadges, forKey: Keys.licenseBadges) }
    }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let providers = "volna.settings.providers.v1"
        static let preferRussian = "volna.settings.preferRussian.v1"
        static let showExplicit = "volna.settings.showExplicit.v1"
        static let licenseBadges = "volna.settings.licenseBadges.v1"
    }

    init() {
        if let stored = defaults.array(forKey: Keys.providers) as? [String], !stored.isEmpty {
            enabledProviderIDs = Set(stored)
        } else {
            enabledProviderIDs = MusicSourceCatalog.defaultEnabledIDs
        }

        if defaults.object(forKey: Keys.preferRussian) == nil {
            preferRussianMusic = true
        } else {
            preferRussianMusic = defaults.bool(forKey: Keys.preferRussian)
        }

        if defaults.object(forKey: Keys.showExplicit) == nil {
            showExplicitContent = true
        } else {
            showExplicitContent = defaults.bool(forKey: Keys.showExplicit)
        }

        if defaults.object(forKey: Keys.licenseBadges) == nil {
            showLicenseBadges = true
        } else {
            showLicenseBadges = defaults.bool(forKey: Keys.licenseBadges)
        }
    }

    func isProviderEnabled(_ id: String) -> Bool {
        enabledProviderIDs.contains(id)
    }

    func setProvider(_ id: String, enabled: Bool) {
        if enabled {
            enabledProviderIDs.insert(id)
        } else {
            enabledProviderIDs.remove(id)
        }
    }

    func resetToDefaults() {
        enabledProviderIDs = MusicSourceCatalog.defaultEnabledIDs
        preferRussianMusic = true
        showExplicitContent = true
        showLicenseBadges = true
    }

    private func saveProviders() {
        defaults.set(Array(enabledProviderIDs).sorted(), forKey: Keys.providers)
    }
}
