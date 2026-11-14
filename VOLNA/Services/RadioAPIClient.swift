import Foundation

/// Контракт сетевого слоя Radio Browser. Позволяет тестировать сервис без
/// реальной сети и не привязывает кэш/пагинацию к URLSession.
protocol RadioAPIClienting: Sendable {
    func stations(for query: RadioStationQuery) async throws -> [RadioStation]
    func countries() async throws -> [RadioCountry]
    func languages(limit: Int) async throws -> [RadioLanguage]
    func tags(limit: Int) async throws -> [RadioGenre]
}

enum RadioAPIError: LocalizedError, Equatable {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)
    case payload
    case transport

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Не удалось сформировать запрос к каталогу радио."
        case .invalidResponse:
            return "Каталог радио вернул неожиданный ответ."
        case .httpStatus(let code):
            if code == 429 {
                return "Каталог радио временно ограничил запросы. Попробуйте через минуту."
            }
            if (500...599).contains(code) {
                return "Каталог радио временно недоступен. Попробуйте позже."
            }
            return "Каталог радио ответил ошибкой \(code)."
        case .payload:
            return "Не удалось разобрать ответ каталога радио."
        case .transport:
            return "Нет соединения с каталогом радио. Проверьте интернет и повторите попытку."
        }
    }
}

/// Клиент открытого API Radio Browser.
///
/// Публичный API не требует ключа. Согласно документации, клиент обязан
/// представляться через User-Agent; также используется GeoDNS-домен `all`,
/// который выбирает доступный сервер автоматически.
actor RadioAPIClient: RadioAPIClienting {
    private let session: URLSession
    private let baseURL: URL
    private let userAgent: String

    init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://all.api.radio-browser.info")!,
        userAgent: String = "VOLNA/1.0 (iOS; radio-browser-client)"
    ) {
        self.session = session
        self.baseURL = baseURL
        self.userAgent = userAgent
    }

    func stations(for query: RadioStationQuery) async throws -> [RadioStation] {
        try await request(
            path: ["json", "stations", "search"],
            queryItems: query.queryItems,
            as: [RadioStation].self
        )
    }

    func countries() async throws -> [RadioCountry] {
        try await request(
            path: ["json", "countries"],
            queryItems: [
                URLQueryItem(name: "hidebroken", value: "true"),
                URLQueryItem(name: "order", value: "stationcount"),
                URLQueryItem(name: "reverse", value: "true"),
                URLQueryItem(name: "limit", value: "300")
            ],
            as: [RadioCountry].self
        )
    }

    func languages(limit: Int = 200) async throws -> [RadioLanguage] {
        try await request(
            path: ["json", "languages"],
            queryItems: [
                URLQueryItem(name: "hidebroken", value: "true"),
                URLQueryItem(name: "order", value: "stationcount"),
                URLQueryItem(name: "reverse", value: "true"),
                URLQueryItem(name: "limit", value: String(min(max(limit, 1), 500)))
            ],
            as: [RadioLanguage].self
        )
    }

    func tags(limit: Int = 200) async throws -> [RadioGenre] {
        try await request(
            path: ["json", "tags"],
            queryItems: [
                URLQueryItem(name: "hidebroken", value: "true"),
                URLQueryItem(name: "order", value: "stationcount"),
                URLQueryItem(name: "reverse", value: "true"),
                URLQueryItem(name: "limit", value: String(min(max(limit, 1), 500)))
            ],
            as: [RadioGenre].self
        )
    }

    // MARK: - Request

    private func request<T: Decodable>(
        path: [String],
        queryItems: [URLQueryItem],
        as type: T.Type
    ) async throws -> T {
        guard var components = URLComponents(
            url: path.reduce(baseURL) { $0.appendingPathComponent($1) },
            resolvingAgainstBaseURL: false
        ) else {
            throw RadioAPIError.invalidURL
        }
        components.queryItems = queryItems
        guard let url = components.url else { throw RadioAPIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 25
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            if error is CancellationError { throw CancellationError() }
            if let urlError = error as? URLError, urlError.code == .cancelled {
                throw CancellationError()
            }
            throw RadioAPIError.transport
        }

        guard let http = response as? HTTPURLResponse else {
            throw RadioAPIError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw RadioAPIError.httpStatus(http.statusCode)
        }

        var payload = data
        if payload.starts(with: [0xEF, 0xBB, 0xBF]) {
            payload.removeFirst(3)
        }

        let decoder = JSONDecoder()
        if let decoded = try? decoder.decode(T.self, from: payload) {
            return decoded
        }
        // Некоторые зеркала Radio Browser исторически отдают массив в
        // обёртке { "value": [...] }. Поддерживаем оба формата.
        if let envelope = try? decoder.decode(RadioEnvelope<T>.self, from: payload) {
            return envelope.value
        }
        throw RadioAPIError.payload
    }
}

private struct RadioEnvelope<T: Decodable>: Decodable {
    let value: T
}
