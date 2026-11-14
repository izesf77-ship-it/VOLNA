import Foundation

/// Радиостанция из открытого каталога Radio Browser.
///
/// Радио принципиально не является музыкальным треком: у станции нет
/// очереди, длительности и позиции воспроизведения. Поэтому это отдельный
/// тип, а не `Track` — плеер обрабатывает его собственным режимом.
///
/// API Radio Browser отдаёт часть полей строками, часть числами, а пустые
/// значения может присылать как `null`, `""` или `0`. Декодирование намеренно
/// терпимое: некорректное поле не должно ронять весь список станций.
struct RadioStation: Identifiable, Codable, Hashable, Sendable {
    let stationUUID: String
    let name: String
    let url: URL?
    let resolvedURL: URL?
    let homepage: URL?
    let favicon: URL?
    let country: String
    let countryCode: String?
    let state: String?
    let language: String
    let languageCodes: [String]
    let tags: [String]
    let codec: String?
    let bitrate: Int?
    let votes: Int?
    let clickCount: Int?
    let lastCheckOK: Bool
    let lastCheckTime: Date?

    var id: String { stationUUID }

    /// Для воспроизведения предпочитаем адрес, который уже разрешил сервер.
    var playbackURL: URL? { resolvedURL ?? url }

    /// Совместимый псевдоним для мест, где исторически ожидается `streamURL`.
    var streamURL: URL? { playbackURL }

    /// Логотип станции, если вещатель его предоставил.
    var artworkURL: URL? { favicon }

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Радио" : trimmed
    }

    /// Станция пригодна для показа и воспроизведения: есть имя и HTTP(S)-поток,
    /// а последняя проверка Radio Browser не отметила её как сломанную.
    var isPlayable: Bool {
        guard lastCheckOK, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        guard let scheme = playbackURL?.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

    var isHTTPS: Bool {
        playbackURL?.scheme?.lowercased() == "https"
    }

    /// Флаг страны из кода ISO 3166-1 (эмодзи региональных индикаторов).
    /// Работает офлайн, API для этого не нужен.
    var flagEmoji: String? {
        CountryFlag.emoji(for: countryCode)
    }

    /// Первый содержательный музыкальный тег для отображения.
    var primaryGenre: String? {
        let noise: Set<String> = [
            "music", "radio", "hits", "talk", "news", "various", "other",
            "local", "live", "fm", "am", "international"
        ]
        for tag in tags {
            let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !noise.contains(trimmed.lowercased()) else { continue }
            return trimmed.capitalized
        }
        return tags.first?.capitalized
    }

    var genreDisplay: String? {
        guard let genre = primaryGenre, !genre.isEmpty else { return nil }
        return genre
    }

    /// «Страна · Регион» для строк каталога.
    var locationText: String {
        var parts: [String] = []
        if let flag = flagEmoji { parts.append(flag) }

        let localizedCountry = countryCode.flatMap { code -> String? in
            let value = Locale(identifier: "ru_RU").localizedString(forRegionCode: code)
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        let countryName = country.trimmingCharacters(in: .whitespacesAndNewlines)
        if let localizedCountry {
            parts.append(localizedCountry)
        } else if !countryName.isEmpty {
            parts.append(countryName)
        }

        if let state {
            let cleanState = state.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanState.isEmpty, cleanState.lowercased() != countryName.lowercased() {
                parts.append(cleanState)
            }
        }
        return parts.joined(separator: " ")
    }

    /// Краткое описание качества потока для карточки: «MP3 · 128 kbps».
    var streamQualityText: String? {
        var parts: [String] = []
        if let codec {
            let clean = codec.trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty { parts.append(clean.uppercased()) }
        }
        if let bitrate, bitrate > 0 {
            parts.append("\(bitrate) kbps")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    init(
        stationUUID: String,
        name: String,
        url: URL?,
        resolvedURL: URL?,
        homepage: URL?,
        favicon: URL?,
        country: String,
        countryCode: String?,
        state: String?,
        language: String,
        languageCodes: [String],
        tags: [String],
        codec: String?,
        bitrate: Int?,
        votes: Int?,
        clickCount: Int?,
        lastCheckOK: Bool,
        lastCheckTime: Date?
    ) {
        self.stationUUID = stationUUID
        self.name = name
        self.url = url
        self.resolvedURL = resolvedURL
        self.homepage = homepage
        self.favicon = favicon
        self.country = country
        self.countryCode = countryCode
        self.state = state
        self.language = language
        self.languageCodes = languageCodes
        self.tags = tags
        self.codec = codec
        self.bitrate = bitrate
        self.votes = votes
        self.clickCount = clickCount
        self.lastCheckOK = lastCheckOK
        self.lastCheckTime = lastCheckTime
    }

    enum CodingKeys: String, CodingKey {
        case stationUUID = "stationuuid"
        case name
        case url
        case resolvedURL = "url_resolved"
        case homepage
        case favicon
        case country
        case countryCode = "countrycode"
        case state
        case language
        case languageCodes = "languagecodes"
        case tags
        case codec
        case bitrate
        case votes
        case clickCount = "clickcount"
        case lastCheckOK = "lastcheckok"
        case lastCheckTime = "lastchecktime"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        stationUUID = container.radioString(.stationUUID)
        name = container.radioString(.name)
        url = container.radioURL(.url)
        resolvedURL = container.radioURL(.resolvedURL)
        homepage = container.radioURL(.homepage)
        favicon = container.radioURL(.favicon)
        country = container.radioString(.country)
        countryCode = container.radioString(.countryCode).radioNilIfEmpty?.uppercased()
        state = container.radioString(.state).radioNilIfEmpty
        language = container.radioString(.language)
        languageCodes = container.radioString(.languageCodes).radioCommaSeparated(limit: 12)
        tags = container.radioString(.tags).radioCommaSeparated(limit: 24)
        codec = container.radioString(.codec).radioNilIfEmpty
        bitrate = container.radioInt(.bitrate)
        votes = container.radioInt(.votes)
        clickCount = container.radioInt(.clickCount)
        lastCheckOK = container.radioBool(.lastCheckOK)
        lastCheckTime = container.radioDate(.lastCheckTime)
    }

    /// Симметрично `init(from:)`: списки пишутся строкой через запятую,
    /// иначе сохранённое избранное после перезапуска теряло теги и языки,
    /// а флаг проверки станции — тип.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(stationUUID, forKey: .stationUUID)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(url, forKey: .url)
        try container.encodeIfPresent(resolvedURL, forKey: .resolvedURL)
        try container.encodeIfPresent(homepage, forKey: .homepage)
        try container.encodeIfPresent(favicon, forKey: .favicon)
        try container.encode(country, forKey: .country)
        try container.encodeIfPresent(countryCode, forKey: .countryCode)
        try container.encodeIfPresent(state, forKey: .state)
        try container.encode(language, forKey: .language)
        try container.encode(languageCodes.joined(separator: ","), forKey: .languageCodes)
        try container.encode(tags.joined(separator: ","), forKey: .tags)
        try container.encodeIfPresent(codec, forKey: .codec)
        try container.encodeIfPresent(bitrate, forKey: .bitrate)
        try container.encodeIfPresent(votes, forKey: .votes)
        try container.encodeIfPresent(clickCount, forKey: .clickCount)
        try container.encode(lastCheckOK ? 1 : 0, forKey: .lastCheckOK)
        try container.encodeIfPresent(lastCheckTime, forKey: .lastCheckTime)
    }

    static func == (lhs: RadioStation, rhs: RadioStation) -> Bool {
        lhs.stationUUID == rhs.stationUUID
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(stationUUID)
    }
}

// MARK: - Country / language / genre

/// Страна для экрана выбора.
struct RadioCountry: Identifiable, Hashable, Codable, Sendable {
    let name: String
    let code: String
    let stationCount: Int

    var id: String { code }

    var displayName: String {
        let localized = Locale(identifier: "ru_RU").localizedString(forRegionCode: code)
        if let localized, !localized.isEmpty { return localized }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? code : trimmed
    }

    var flagEmoji: String? { CountryFlag.emoji(for: code) }

    enum CodingKeys: String, CodingKey {
        case name
        case code = "iso_3166_1"
        case stationCount = "stationcount"
    }

    init(name: String, code: String, stationCount: Int) {
        self.name = name
        self.code = code
        self.stationCount = stationCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = container.radioString(.name)
        code = container.radioString(.code).uppercased()
        stationCount = container.radioInt(.stationCount) ?? 0
    }
}

/// Язык для экрана выбора.
struct RadioLanguage: Identifiable, Hashable, Codable, Sendable {
    let name: String
    let code: String?
    let stationCount: Int

    var id: String { code ?? name }

    var displayName: String {
        let localized = code.flatMap { Locale(identifier: "ru_RU").localizedString(forLanguageCode: $0) }
        if let localized, !localized.isEmpty { return localized.capitalized }
        return name.trimmingCharacters(in: .whitespacesAndNewlines).capitalized
    }

    enum CodingKeys: String, CodingKey {
        case name
        case code = "iso_639"
        case stationCount = "stationcount"
    }

    init(name: String, code: String?, stationCount: Int) {
        self.name = name
        self.code = code
        self.stationCount = stationCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = container.radioString(.name)
        code = container.radioString(.code).radioNilIfEmpty
        stationCount = container.radioInt(.stationCount) ?? 0
    }
}

/// Жанр (тег) для экрана выбора.
struct RadioGenre: Identifiable, Hashable, Codable, Sendable {
    let name: String
    let stationCount: Int

    var id: String { name }
    var displayName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).capitalized
    }

    enum CodingKeys: String, CodingKey {
        case name
        case stationCount = "stationcount"
    }

    init(name: String, stationCount: Int) {
        self.name = name
        self.stationCount = stationCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = container.radioString(.name)
        stationCount = container.radioInt(.stationCount) ?? 0
    }
}

/// Курируемый список жанров для витрины. API принимает тег как есть, а UI
/// показывает русское название — это не подмена данных, а только подпись.
struct RadioGenreOption: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let icon: String
}

enum RadioGenreCatalog {
    static let all: [RadioGenreOption] = [
        RadioGenreOption(id: "pop", title: "Поп", icon: "sparkles"),
        RadioGenreOption(id: "rock", title: "Рок", icon: "guitars"),
        RadioGenreOption(id: "electronic", title: "Электроника", icon: "waveform.path.ecg"),
        RadioGenreOption(id: "dance", title: "Танцевальная", icon: "figure.dance"),
        RadioGenreOption(id: "jazz", title: "Джаз", icon: "music.quarternote.3"),
        RadioGenreOption(id: "classical", title: "Классика", icon: "pianokeys"),
        RadioGenreOption(id: "hip hop", title: "Хип-хоп", icon: "mic"),
        RadioGenreOption(id: "metal", title: "Метал", icon: "bolt.fill"),
        RadioGenreOption(id: "reggae", title: "Регги", icon: "sun.max"),
        RadioGenreOption(id: "blues", title: "Блюз", icon: "guitars"),
        RadioGenreOption(id: "country", title: "Кантри", icon: "mountain.2"),
        RadioGenreOption(id: "folk", title: "Фолк", icon: "leaf"),
        RadioGenreOption(id: "news", title: "Новости", icon: "newspaper"),
        RadioGenreOption(id: "talk", title: "Разговорное", icon: "bubble.left.and.bubble.right"),
        RadioGenreOption(id: "chillout", title: "Chillout", icon: "moon.stars"),
        RadioGenreOption(id: "retro", title: "Ретро", icon: "clock.arrow.circlepath")
    ]

    static func stationCount(for id: String, in genres: [RadioGenre]) -> Int? {
        genres.first { $0.name.caseInsensitiveCompare(id) == .orderedSame }?.stationCount
    }
}

// MARK: - Flags

enum CountryFlag {
    static func emoji(for code: String?) -> String? {
        guard let code = code?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
              code.count == 2 else {
            return nil
        }
        let scalars = code.unicodeScalars.compactMap { scalar -> Unicode.Scalar? in
            guard scalar.value >= 65, scalar.value <= 90 else { return nil }
            return Unicode.Scalar(0x1F1E6 + (scalar.value - 65))
        }
        guard scalars.count == 2 else { return nil }
        return String(String.UnicodeScalarView(scalars))
    }
}

// MARK: - Query / page

enum RadioStationOrder: String, Codable, Hashable, Sendable {
    case clickCount = "clickcount"
    case votes
    case lastCheckTime = "lastchecktime"
    case lastChangeTime = "lastchangetime"
    case name
    case random
}

/// Параметры одного запроса к `/json/stations/search`.
///
/// Отдельная структура позволяет тестировать сборку query без сети и
/// гарантирует, что для русского языка используется `language=russian`,
/// а не ненадёжный `languagecodes=ru`.
struct RadioStationQuery: Hashable, Sendable {
    var name: String? = nil
    var countryCode: String? = nil
    var language: String? = nil
    var tag: String? = nil
    var order: RadioStationOrder = .clickCount
    var reverse = true
    var offset = 0
    var limit = 40
    var hideBroken = true

    var normalizedLimit: Int { min(max(limit, 1), 100) }
    var normalizedOffset: Int { max(offset, 0) }

    var queryItems: [URLQueryItem] {
        var items: [URLQueryItem] = []
        if let name = name?.radioTrimmedNonEmpty {
            items.append(URLQueryItem(name: "name", value: name))
        }
        if let countryCode = countryCode?.radioTrimmedNonEmpty {
            items.append(URLQueryItem(name: "countrycode", value: countryCode.uppercased()))
        }
        if let language = language?.radioTrimmedNonEmpty {
            items.append(URLQueryItem(name: "language", value: language.lowercased()))
        }
        if let tag = tag?.radioTrimmedNonEmpty {
            items.append(URLQueryItem(name: "tag", value: tag.lowercased()))
        }
        items.append(URLQueryItem(name: "order", value: order.rawValue))
        items.append(URLQueryItem(name: "reverse", value: reverse ? "true" : "false"))
        items.append(URLQueryItem(name: "offset", value: String(normalizedOffset)))
        items.append(URLQueryItem(name: "limit", value: String(normalizedLimit)))
        if hideBroken {
            items.append(URLQueryItem(name: "hidebroken", value: "true"))
        }
        return items
    }

    var cacheKey: String {
        queryItems
            .sorted { $0.name < $1.name }
            .map { "\($0.name)=\($0.value ?? "")" }
            .joined(separator: "&")
    }

    var nextPage: RadioStationQuery {
        var copy = self
        copy.offset = normalizedOffset + normalizedLimit
        return copy
    }

    static func popular(limit: Int = 20) -> RadioStationQuery {
        RadioStationQuery(order: .clickCount, reverse: true, offset: 0, limit: limit)
    }

    static func russian(limit: Int = 20) -> RadioStationQuery {
        RadioStationQuery(language: "russian", order: .clickCount, reverse: true, offset: 0, limit: limit)
    }

    static func international(limit: Int = 40) -> RadioStationQuery {
        RadioStationQuery(order: .clickCount, reverse: true, offset: 0, limit: limit)
    }

    static func newStations(limit: Int = 20) -> RadioStationQuery {
        RadioStationQuery(order: .lastChangeTime, reverse: true, offset: 0, limit: limit)
    }

    static func country(_ code: String, limit: Int = 40) -> RadioStationQuery {
        RadioStationQuery(countryCode: code, order: .clickCount, reverse: true, offset: 0, limit: limit)
    }

    static func genre(_ tag: String, limit: Int = 40) -> RadioStationQuery {
        RadioStationQuery(tag: tag, order: .clickCount, reverse: true, offset: 0, limit: limit)
    }

    static func language(_ language: String, limit: Int = 40) -> RadioStationQuery {
        RadioStationQuery(language: language, order: .clickCount, reverse: true, offset: 0, limit: limit)
    }

    static func search(_ text: String, limit: Int = 30) -> RadioStationQuery {
        RadioStationQuery(name: text, order: .clickCount, reverse: true, offset: 0, limit: limit)
    }
}

/// Одна страница результатов с информацией для пагинации.
struct RadioPage: Sendable {
    let stations: [RadioStation]
    let nextOffset: Int?
    let hasMore: Bool
    let receivedCount: Int

    var nextQuery: RadioStationQuery? {
        guard hasMore, let nextOffset else { return nil }
        var query = self.query
        query.offset = nextOffset
        return query
    }

    let query: RadioStationQuery
}

enum RadioPaginator {
    /// Строит страницу по сырому ответу API. `receivedCount` считается до
    /// фильтрации: иначе смещение следующей страницы «поехало» бы на
    /// отброшенных станциях.
    static func page(raw: [RadioStation], query: RadioStationQuery) -> RadioPage {
        let filtered = RadioStationFilter.normalize(raw, limit: query.normalizedLimit)
        let hasMore = raw.count >= query.normalizedLimit
        return RadioPage(
            stations: filtered,
            nextOffset: hasMore ? query.normalizedOffset + raw.count : nil,
            hasMore: hasMore,
            receivedCount: raw.count,
            query: query
        )
    }
}

enum RadioStationFilter {
    /// Убирает сломанные/пустые станции и дубли по UUID, сохраняя порядок.
    static func normalize(_ stations: [RadioStation], limit: Int? = nil) -> [RadioStation] {
        var seen = Set<String>()
        var result: [RadioStation] = []
        result.reserveCapacity(limit ?? stations.count)

        for station in stations where station.isPlayable {
            let key = station.stationUUID.lowercased()
            guard !key.isEmpty else { continue }
            guard seen.insert(key).inserted else { continue }
            result.append(station)
            if let limit, result.count >= limit { break }
        }
        return result
    }

    /// Оставляет только станции без русского языка. Используется для
    /// международной витрины, где API не умеет исключать язык.
    static func internationalOnly(_ stations: [RadioStation]) -> [RadioStation] {
        stations.filter { station in
            let languages = station.language.lowercased()
            return !languages.contains("russian")
                && station.countryCode?.uppercased() != "RU"
                && station.countryCode?.uppercased() != "BY"
        }
    }
}

// MARK: - Tolerant decoding helpers

private extension KeyedDecodingContainer {
    func radioString(_ key: Key) -> String {
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return RadioText.clean(value)
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return String(value)
        }
        if let value = try? decodeIfPresent(Bool.self, forKey: key) {
            return value ? "1" : "0"
        }
        return ""
    }

    func radioInt(_ key: Key) -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return Int(value)
        }
        if let value = try? decodeIfPresent(Bool.self, forKey: key) {
            return value ? 1 : 0
        }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return Int(RadioText.clean(value))
        }
        return nil
    }

    func radioBool(_ key: Key) -> Bool {
        if let value = try? decodeIfPresent(Bool.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return value != 0
        }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            switch RadioText.clean(value).lowercased() {
            case "1", "true", "yes", "ok": return true
            case "0", "false", "no": return false
            default: return false
            }
        }
        return false
    }

    func radioURL(_ key: Key) -> URL? {
        let raw = radioString(key)
        guard let url = URL(string: raw),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return nil
        }
        return url
    }

    /// Локальное избранное хранит `Date` в нативном формате JSONEncoder,
    /// а Radio Browser присылает дату строкой — поддерживаем оба варианта.
    func radioDate(_ key: Key) -> Date? {
        if let value = try? decodeIfPresent(Date.self, forKey: key) {
            return value
        }
        return RadioDateParser.parse(radioString(key))
    }
}

private enum RadioText {
    static func clean(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "\0", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension String {
    var radioNilIfEmpty: String? {
        radioTrimmedNonEmpty
    }

    var radioTrimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func radioCommaSeparated(limit: Int) -> [String] {
        var seen = Set<String>()
        var values: [String] = []
        for part in split(separator: ",") {
            let value = String(part).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { continue }
            let key = value.lowercased()
            guard seen.insert(key).inserted else { continue }
            values.append(value)
            if values.count >= limit { break }
        }
        return values
    }
}

private enum RadioDateParser {
    static func parse(_ raw: String) -> Date? {
        guard !raw.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: raw)
    }
}
