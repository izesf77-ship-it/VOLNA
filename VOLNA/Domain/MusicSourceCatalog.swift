import Foundation

struct MusicSourceInfo: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let shortName: String
    let description: String
    let websiteURL: URL?
    let licenseSummary: String
    let rateLimitNote: String
    let requiresKey: Bool
    let supportsRussian: Bool
    let priority: Double
}

enum MusicSourceCatalog {
    static let all: [MusicSourceInfo] = [
        MusicSourceInfo(
            id: "jamendo",
            name: "Jamendo",
            shortName: "Jamendo",
            description: "Крупнейший каталог независимой музыки под лицензиями Creative Commons. Прямые MP3-потоки и данные лицензии для каждого трека.",
            websiteURL: URL(string: "https://www.jamendo.com/"),
            licenseSummary: "Creative Commons: CC BY, BY-SA, BY-ND, BY-NC, BY-NC-SA, BY-NC-ND",
            rateLimitNote: "Публичный Client ID. Ограничение API зависит от тарифа приложения Jamendo.",
            requiresKey: false,
            supportsRussian: true,
            priority: 1.00
        ),
        MusicSourceInfo(
            id: "internet_archive",
            name: "Internet Archive",
            shortName: "Archive",
            description: "Публичный архив аудиозаписей. VOLNA показывает только элементы с указанной лицензией и воспроизводит MP3-производные.",
            websiteURL: URL(string: "https://archive.org/details/audio"),
            licenseSummary: "Разные лицензии; в поиск попадают только элементы с указанным licenseurl",
            rateLimitNote: "Публичный Search API и Metadata API без ключа. Рекомендуется умеренная частота запросов.",
            requiresKey: false,
            supportsRussian: true,
            priority: 0.85
        ),
        MusicSourceInfo(
            id: "wikimedia_commons",
            name: "Wikimedia Commons",
            shortName: "Commons",
            description: "Свободные аудиофайлы Викисклада. Для OGG/Opus используется официальная MP3-транскодия Wikimedia.",
            websiteURL: URL(string: "https://commons.wikimedia.org/"),
            licenseSummary: "CC0, Public Domain, CC BY, CC BY-SA и другие свободные лицензии",
            rateLimitNote: "Публичный MediaWiki API без ключа. Указан описательный User-Agent.",
            requiresKey: false,
            supportsRussian: true,
            priority: 0.75
        ),
        MusicSourceInfo(
            id: "openverse",
            name: "Openverse",
            shortName: "Openverse",
            description: "Открытый поисковый индекс CC-аудио. Дополняет каталоги Jamendo и Wikimedia, не создавая собственных аудиофайлов.",
            websiteURL: URL(string: "https://openverse.org/"),
            licenseSummary: "Только Creative Commons и общественное достояние",
            rateLimitNote: "Анонимный лимит: 20 запросов/мин и 200 запросов/сутки на IP.",
            requiresKey: false,
            supportsRussian: true,
            priority: 0.65
        ),
        MusicSourceInfo(
            id: "direct",
            name: "Прямые ссылки",
            shortName: "Direct",
            description: "Ваши собственные HTTPS-ссылки на MP3, AAC, M4A, WAV, FLAC или HLS. Ссылка проверяется по HTTP-заголовкам перед добавлением.",
            websiteURL: nil,
            licenseSummary: "Лицензию указывает пользователь; неизвестная лицензия не считается свободной",
            rateLimitNote: "Локальный источник, сеть используется только для проверки ссылки.",
            requiresKey: false,
            supportsRussian: true,
            priority: 0.40
        )
    ]

    static func info(for id: String) -> MusicSourceInfo? {
        all.first { $0.id == id }
    }

    static var defaultEnabledIDs: Set<String> {
        Set(all.map(\.id))
    }
}
