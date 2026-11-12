import Foundation

/// Результат проверки прямой аудиоссылки.
struct DirectAudioValidation: Sendable {
    let finalURL: URL
    let format: AudioFormat
    let contentType: String
    let contentLength: Int64?
    let supportsRangeRequests: Bool
    let statusCode: Int
    let isHLS: Bool
}

/// Проверяет прямые HTTPS-ссылки перед добавлением в медиатеку.
///
/// Проверяются: схема HTTPS, HTTP-статус, Content-Type, финальный URL после
/// редиректов, поддержка Range-запросов и размер файла. HTML и прочие
/// неаудиоответы отклоняются — приложение никогда не пытается «играть» веб-
/// страницу вместо аудио.
actor DirectAudioValidator {
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 25
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpAdditionalHeaders = [
            "User-Agent": "VOLNA/1.0 (iOS; direct audio validation)",
            "Accept": "audio/*,application/vnd.apple.mpegurl,application/octet-stream;q=0.8,*/*;q=0.1"
        ]
        self.session = URLSession(configuration: configuration)
    }

    func validate(_ url: URL) async throws -> DirectAudioValidation {
        guard url.scheme?.lowercased() == "https" else {
            throw DirectAudioError.insecureURL
        }
        guard let host = url.host, !host.isEmpty else {
            throw DirectAudioError.invalidURL
        }

        var headResult: (HTTPURLResponse, URL)?
        do {
            headResult = try await head(url)
        } catch {
            headResult = nil
        }

        if let (response, finalURL) = headResult,
           response.statusCode == 200 || response.statusCode == 206 {
            return try makeValidation(response: response, finalURL: finalURL, ranged: response.statusCode == 206)
        }

        // Некоторые CDN не поддерживают HEAD. Пробуем безопасный Range-запрос,
        // читая только первые байты.
        let (response, finalURL, gotPartial) = try await rangedProbe(url)
        return try makeValidation(response: response, finalURL: finalURL, ranged: gotPartial)
    }

    // MARK: - Probes

    private func head(_ url: URL) async throws -> (HTTPURLResponse, URL) {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 15
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw DirectAudioError.invalidResponse
        }
        return (http, response.url ?? url)
    }

    private func rangedProbe(_ url: URL) async throws -> (HTTPURLResponse, URL, Bool) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("bytes=0-2047", forHTTPHeaderField: "Range")
        request.timeoutInterval = 15

        let (bytes, response) = try await session.bytes(for: request)
        // Читаем максимум один байт, чтобы не скачивать файл целиком.
        var iterator = bytes.makeAsyncIterator()
        _ = try? await iterator.next()

        guard let http = response as? HTTPURLResponse else {
            throw DirectAudioError.invalidResponse
        }
        let ranged = http.statusCode == 206
        if http.statusCode != 200 && http.statusCode != 206 {
            throw DirectAudioError.httpStatus(http.statusCode)
        }
        return (http, response.url ?? url, ranged)
    }

    private func makeValidation(
        response: HTTPURLResponse,
        finalURL: URL,
        ranged: Bool
    ) throws -> DirectAudioValidation {
        guard finalURL.scheme?.lowercased() == "https" else {
            throw DirectAudioError.insecureURL
        }

        let rawContentType = (response.value(forHTTPHeaderField: "Content-Type") ?? "")
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let mime = rawContentType
            .split(separator: ";", maxSplits: 1)
            .first
            .map(String.init) ?? ""

        if mime.contains("text/html") || mime.contains("application/xhtml") ||
            mime.contains("application/json") || mime.contains("text/plain") {
            throw DirectAudioError.notAudio(mime)
        }

        let isHLS = mime.contains("mpegurl")
            || finalURL.pathExtension.lowercased() == "m3u8"
            || mime.contains("vnd.apple")

        let format: AudioFormat
        if isHLS {
            format = .hls
        } else {
            format = AudioFormat.from(mimeType: mime, pathExtension: finalURL.pathExtension)
        }

        guard format != .unknown else {
            throw DirectAudioError.unsupportedFormat
        }
        guard format.isPlayableByAVPlayer else {
            throw DirectAudioError.unsupportedFormat
        }

        if !isHLS {
            let isAudioMime = mime.hasPrefix("audio/")
                || mime == "application/octet-stream"
            guard isAudioMime else {
                throw DirectAudioError.notAudio(mime)
            }
        }

        let lengthHeader = response.value(forHTTPHeaderField: "Content-Length")
        let contentLength = lengthHeader.flatMap { Int64($0) }
        let acceptRanges = (response.value(forHTTPHeaderField: "Accept-Ranges") ?? "")
            .lowercased()
            .contains("bytes")
        let contentRange = response.value(forHTTPHeaderField: "Content-Range")

        return DirectAudioValidation(
            finalURL: finalURL,
            format: format,
            contentType: rawContentType.isEmpty ? "audio/*" : rawContentType,
            contentLength: contentLength,
            supportsRangeRequests: ranged || acceptRanges || contentRange != nil || isHLS,
            statusCode: response.statusCode,
            isHLS: isHLS
        )
    }
}

enum DirectAudioError: Error, LocalizedError {
    case insecureURL
    case invalidURL
    case invalidResponse
    case httpStatus(Int)
    case notAudio(String)
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .insecureURL:
            return "Разрешены только HTTPS-ссылки"
        case .invalidURL:
            return "Некорректная ссылка"
        case .invalidResponse:
            return "Сервер вернул некорректный ответ"
        case .httpStatus(let code):
            return "Сервер вернул HTTP \(code)"
        case .notAudio(let mime):
            if mime.isEmpty {
                return "Ссылка не является аудиофайлом"
            }
            return "Ссылка не является аудиофайлом (Content-Type: \(mime))"
        case .unsupportedFormat:
            return "Формат не поддерживается AVPlayer. Используйте MP3, AAC, M4A, WAV, FLAC или HLS."
        }
    }
}
