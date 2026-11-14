import Foundation

/// Реальная композиция из ICY-метаданных станции.
///
/// Поля заполняются только из `StreamTitle`; если вещатель не передаёт
/// метаданные, значение остаётся `nil` и UI показывает только название станции.
struct ICYNowPlaying: Equatable, Sendable {
    let rawTitle: String
    let artist: String?
    let title: String

    var displayText: String {
        if let artist, !artist.isEmpty {
            return "\(artist) — \(title)"
        }
        return title
    }

    var secondaryText: String {
        if let artist, !artist.isEmpty { return artist }
        return "Сейчас в эфире"
    }
}

enum ICYMetadataParser {
    static func parse(_ data: Data) -> ICYNowPlaying? {
        guard !data.isEmpty else { return nil }
        let text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .windowsCP1251)
            ?? String(data: data, encoding: .isoLatin1)
        guard let text else { return nil }
        return parse(text)
    }

    static func parse(_ text: String) -> ICYNowPlaying? {
        let marker = "StreamTitle='"
        guard let markerRange = text.range(of: marker, options: [.caseInsensitive]) else {
            return nil
        }

        let rest = text[markerRange.upperBound...]
        guard let endRange = rest.range(of: "';") else { return nil }
        let raw = String(rest[..<endRange.lowerBound])
            .replacingOccurrences(of: "\\'", with: "'")
            .replacingOccurrences(of: "\\\\", with: "\\")
        let cleaned = raw
            .replacingOccurrences(of: "\0", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }

        if let separator = cleaned.range(of: " - ") {
            let artist = String(cleaned[..<separator.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let title = String(cleaned[separator.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !artist.isEmpty, !title.isEmpty {
                return ICYNowPlaying(rawTitle: cleaned, artist: artist, title: title)
            }
        }

        return ICYNowPlaying(rawTitle: cleaned, artist: nil, title: cleaned)
    }
}

/// Короткий ICY-зонд. AVPlayer на iOS не отдаёт `StreamTitle` для обычных
/// MP3/AAC-потоков, поэтому для метаданных открывается отдельное соединение
/// с `Icy-MetaData: 1`. После первого блока чтение прекращается; аудиоданные
/// не сохраняются.
struct ICYMetadataClient: Sendable {
    func fetch(from url: URL, timeout: TimeInterval = 18) async -> ICYNowPlaying? {
        guard url.scheme?.lowercased() == "https" else { return nil }

        return await withTaskGroup(of: ICYNowPlaying?.self) { group in
            group.addTask {
                await readFirstBlock(from: url)
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(max(timeout, 1) * 1_000_000_000))
                return nil
            }

            let result = await group.next() ?? nil
            group.cancelAll()
            return result
        }
    }

    private func readFirstBlock(from url: URL) async -> ICYNowPlaying? {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 18
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("1", forHTTPHeaderField: "Icy-MetaData")
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("VOLNA/1.0 (iOS; icy-metadata)", forHTTPHeaderField: "User-Agent")

        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode),
                  let rawInterval = http.value(forHTTPHeaderField: "icy-metaint"),
                  let interval = Int(rawInterval),
                  interval > 0,
                  interval < 1_000_000 else {
                return nil
            }

            var iterator = bytes.makeAsyncIterator()
            var remainingAudio = interval
            while remainingAudio > 0 {
                guard try await iterator.next() != nil else { return nil }
                remainingAudio -= 1
            }

            guard let lengthByte = try await iterator.next() else { return nil }
            let metadataLength = Int(lengthByte) * 16
            guard metadataLength > 0 else { return nil }

            var metadata = Data()
            metadata.reserveCapacity(metadataLength)
            while metadata.count < metadataLength {
                guard let byte = try await iterator.next() else { return nil }
                metadata.append(byte)
            }
            return ICYMetadataParser.parse(metadata)
        } catch {
            return nil
        }
    }
}
