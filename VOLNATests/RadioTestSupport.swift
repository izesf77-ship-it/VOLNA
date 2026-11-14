import Foundation
@testable import VOLNA

/// Общие фабрики для тестов радио. Отдельный файл, чтобы не дублировать
/// длинные инициализаторы моделей в каждом наборе тестов.
enum RadioTestSupport {
    static func station(
        id: String = UUID().uuidString,
        name: String = "Radio Test",
        url: String? = "https://127.0.0.1:9/live.mp3",
        resolvedURL: String? = nil,
        country: String = "Germany",
        countryCode: String? = "DE",
        state: String? = nil,
        language: String = "german",
        languageCodes: [String] = [],
        tags: [String] = ["pop"],
        codec: String? = "MP3",
        bitrate: Int? = 128,
        lastCheckOK: Bool = true
    ) -> RadioStation {
        RadioStation(
            stationUUID: id,
            name: name,
            url: url.flatMap { URL(string: $0) },
            resolvedURL: resolvedURL.flatMap { URL(string: $0) },
            homepage: URL(string: "https://example.com/radio"),
            favicon: URL(string: "https://example.com/favicon.png"),
            country: country,
            countryCode: countryCode,
            state: state,
            language: language,
            languageCodes: languageCodes,
            tags: tags,
            codec: codec,
            bitrate: bitrate,
            votes: 10,
            clickCount: 20,
            lastCheckOK: lastCheckOK,
            lastCheckTime: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    static func track(
        id: String = "track-1",
        title: String = "Тестовый трек",
        artist: String = "Тестовый исполнитель",
        stream: String = "https://127.0.0.1:9/track.mp3"
    ) -> Track {
        let source = StreamSource(
            providerID: "jamendo",
            streamURL: URL(string: stream)!,
            format: .mp3,
            license: .ccBy
        )
        return Track(
            id: id,
            title: title,
            artist: artist,
            duration: 180,
            providerID: "jamendo",
            sourceID: id,
            availableStreams: [source],
            license: .ccBy,
            isStreamAllowed: true
        )
    }
}
