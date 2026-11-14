import Foundation
import Observation

/// Каталог интернет-радио поверх открытого API Radio Browser.
///
/// Сервис держит только небольшие витрины и кэш запросов: весь мировой каталог
/// (десятки тысяч станций) никогда не загружается целиком. Одинаковые запросы
/// объединяются в один Task, поэтому переключение вкладок и повторные
/// появления экрана не создают лавину сетевых вызовов.
@MainActor
@Observable
final class RadioService {
    // MARK: - Observable state

    private(set) var popular: [RadioStation] = []
    private(set) var russian: [RadioStation] = []
    private(set) var international: [RadioStation] = []
    private(set) var newStations: [RadioStation] = []
    private(set) var countries: [RadioCountry] = []
    private(set) var languages: [RadioLanguage] = []
    private(set) var genres: [RadioGenre] = []

    private(set) var isFeedLoading = false
    private(set) var isPopularLoading = false
    private(set) var isDirectoryLoading = false
    private(set) var feedError: String?
    private(set) var directoryError: String?
    private(set) var lastFeedUpdate: Date?
    private(set) var lastDirectoryUpdate: Date?

    // MARK: - Dependencies

    private let api: any RadioAPIClienting
    private let pageCacheLifetime: TimeInterval
    private let directoryCacheLifetime: TimeInterval

    private struct CachedPage {
        let page: RadioPage
        let storedAt: Date
    }

    private var pageCache: [String: CachedPage] = [:]
    private var pageTasks: [String: Task<RadioPage, Error>] = [:]
    /// Отдельная отметка полной витрины. Главная загружает только популярные
    /// станции и обновляет `lastFeedUpdate`; если использовать его и здесь,
    /// переход во вкладку «Радио» пропустил бы русские, международные и новые
    /// подборки на 15 минут.
    private var lastFullFeedUpdate: Date?

    init(
        api: any RadioAPIClienting = RadioAPIClient(),
        pageCacheLifetime: TimeInterval = 10 * 60,
        directoryCacheLifetime: TimeInterval = 12 * 60 * 60
    ) {
        self.api = api
        self.pageCacheLifetime = pageCacheLifetime
        self.directoryCacheLifetime = directoryCacheLifetime
    }

    // MARK: - Station pages

    /// Одна страница станций с кэшем и объединением одинаковых запросов.
    func stations(
        for query: RadioStationQuery,
        bypassCache: Bool = false
    ) async throws -> RadioPage {
        let key = query.cacheKey

        if !bypassCache, let cached = pageCache[key], isFresh(cached.storedAt, lifetime: pageCacheLifetime) {
            return cached.page
        }
        if let existing = pageTasks[key] {
            return try await existing.value
        }

        let task = Task<RadioPage, Error> { [api, query] in
            let raw = try await api.stations(for: query)
            return RadioPaginator.page(raw: raw, query: query)
        }
        pageTasks[key] = task

        do {
            let page = try await task.value
            pageTasks[key] = nil
            pageCache[key] = CachedPage(page: page, storedAt: Date())
            if pageCache.count > 80 {
                pageCache.removeAll()
                pageCache[key] = CachedPage(page: page, storedAt: Date())
            }
            return page
        } catch {
            pageTasks[key] = nil
            throw error
        }
    }

    func search(_ text: String) async throws -> RadioPage {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return RadioPage(
                stations: [],
                nextOffset: nil,
                hasMore: false,
                receivedCount: 0,
                query: .search("")
            )
        }
        return try await stations(for: .search(trimmed, limit: 30))
    }

    // MARK: - Feed

    /// Компактная подборка для главной: только популярные станции.
    func loadPopularIfNeeded(force: Bool = false) async {
        guard !isPopularLoading else { return }
        if !force, !popular.isEmpty, let lastFeedUpdate,
           isFresh(lastFeedUpdate, lifetime: 15 * 60) {
            return
        }

        isPopularLoading = true
        do {
            let page = try await stations(for: .popular(limit: 30), bypassCache: force)
            popular = page.stations
            lastFeedUpdate = Date()
            if feedError != nil { feedError = nil }
        } catch is CancellationError {
            // Экран ушёл — это не ошибка каталога.
        } catch {
            if popular.isEmpty {
                feedError = message(for: error)
            }
        }
        isPopularLoading = false
    }

    /// Полная витрина вкладки «Радио». Четыре небольших запроса, не весь каталог.
    func loadFeedIfNeeded(force: Bool = false) async {
        guard !isFeedLoading else { return }
        if !force, let lastFullFeedUpdate,
           !popular.isEmpty,
           isFresh(lastFullFeedUpdate, lifetime: 15 * 60) {
            return
        }

        isFeedLoading = true
        async let popularResult = fetchPage(.popular(limit: 40), force: force)
        async let russianResult = fetchPage(.russian(limit: 30), force: force)
        async let internationalResult = fetchPage(.international(limit: 80), force: force)
        async let newResult = fetchPage(.newStations(limit: 24), force: force)

        let (popularPage, russianPage, internationalPage, newPage) = await (
            popularResult,
            russianResult,
            internationalResult,
            newResult
        )

        guard !Task.isCancelled else {
            isFeedLoading = false
            return
        }

        var failures = 0
        if case .success(let page) = popularPage {
            popular = page.stations
        } else {
            failures += 1
        }
        if case .success(let page) = russianPage {
            russian = page.stations
        } else {
            failures += 1
        }
        if case .success(let page) = internationalPage {
            let filtered = RadioStationFilter.internationalOnly(page.stations)
            international = Array(filtered.prefix(30))
        } else {
            failures += 1
        }
        if case .success(let page) = newPage {
            newStations = Array(page.stations.prefix(20))
        } else {
            failures += 1
        }

        // Международная витрина не должна оставаться пустой, если глобальный
        // запрос не дал достаточного результата после фильтрации.
        if international.isEmpty, !popular.isEmpty {
            international = Array(RadioStationFilter.internationalOnly(popular).prefix(30))
        }

        if failures == 4 {
            let firstError: Error
            if case .failure(let error) = popularPage {
                firstError = error
            } else {
                firstError = RadioAPIError.transport
            }
            feedError = message(for: firstError)
        } else {
            feedError = nil
        }

        if failures < 4 {
            // Слабые сбои не должны заставлять пользователя ждать 15 минут,
            // но и нельзя считать витрину полностью загруженной.
            lastFeedUpdate = Date()
        }
        if failures == 0 {
            lastFullFeedUpdate = Date()
        }
        isFeedLoading = false
    }

    // MARK: - Directory (countries / languages / genres)

    func loadDirectoryIfNeeded(force: Bool = false) async {
        guard !isDirectoryLoading else { return }
        if !force, let lastDirectoryUpdate,
           !countries.isEmpty,
           isFresh(lastDirectoryUpdate, lifetime: directoryCacheLifetime) {
            return
        }

        isDirectoryLoading = true
        async let countriesResult = fetchCountries()
        async let languagesResult = fetchLanguages()
        async let genresResult = fetchGenres()

        let (countryList, languageList, genreList) = await (
            countriesResult,
            languagesResult,
            genresResult
        )

        guard !Task.isCancelled else {
            isDirectoryLoading = false
            return
        }

        var failures = 0
        if let countryList {
            countries = countryList
                .filter { !$0.code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .sorted { $0.stationCount > $1.stationCount }
        } else {
            failures += 1
        }
        if let languageList {
            languages = languageList
                .filter { $0.stationCount > 0 }
                .sorted { $0.stationCount > $1.stationCount }
        } else {
            failures += 1
        }
        if let genreList {
            genres = genreList
                .filter { $0.stationCount > 0 }
                .sorted { $0.stationCount > $1.stationCount }
        } else {
            failures += 1
        }

        if failures == 3, countries.isEmpty, genres.isEmpty {
            directoryError = message(for: RadioAPIError.transport)
        } else if failures > 0, countries.isEmpty || genres.isEmpty {
            directoryError = "Часть справочников радио временно недоступна."
        } else {
            directoryError = nil
        }

        if failures < 3 {
            lastDirectoryUpdate = Date()
        }
        isDirectoryLoading = false
    }

    // MARK: - Helpers

    private func fetchPage(
        _ query: RadioStationQuery,
        force: Bool
    ) async -> Result<RadioPage, Error> {
        do {
            return .success(try await stations(for: query, bypassCache: force))
        } catch {
            return .failure(error)
        }
    }

    private func fetchCountries() async -> [RadioCountry]? {
        try? await api.countries()
    }

    private func fetchLanguages() async -> [RadioLanguage]? {
        try? await api.languages(limit: 200)
    }

    private func fetchGenres() async -> [RadioGenre]? {
        try? await api.tags(limit: 200)
    }

    private func isFresh(_ date: Date, lifetime: TimeInterval) -> Bool {
        guard lifetime > 0 else { return false }
        return Date().timeIntervalSince(date) < lifetime
    }

    private func message(for error: Error) -> String {
        if let radioError = error as? RadioAPIError {
            return radioError.localizedDescription
        }
        return "Не удалось загрузить каталог радио. Проверьте соединение и повторите попытку."
    }
}
