import Foundation

/// Единые правила качества каталога.
///
/// VOLNA не генерирует музыку и не переименовывает записи. Фильтр отсекает
/// служебные/демонстрационные файлы, караоке, минусовки и материалы без
/// подтверждённой лицензии. Всё, что остаётся, пришло из API источника
/// вместе с названием, исполнителем, обложкой и лицензией.
enum CatalogQuality {
    /// Токены, которые почти всегда означают служебный файл, а не песню.
    /// Проверяются только как отдельные слова — «Sound of Silence» остаётся.
    private static let noiseTokens: Set<String> = [
        "demo", "демо", "test", "тест", "sample", "сэмпл", "snippet",
        "teaser", "untitled", "noise", "jingle", "karaoke", "караоке",
        "минус", "минусовка", "backing", "podcast", "подкаст",
        "audiobook", "аудиокнига", "lecture", "лекция", "interview",
        "интервью", "soundcheck", "promo", "промо", "voiceover"
    ]

    private static let noisyPhrases: [String] = [
        "demo version", "демо версия", "test record", "test track",
        "караоке версия", "karaoke version", "backing track",
        "instrumental minus", "минусовая фонограмма", "без вокала",
        "all rights reserved", "служебная запись"
    ]

    private static let coverTokens: Set<String> = [
        "cover", "кавер", "tribute", "трибьют"
    ]

    private static let unknownArtists: Set<String> = Set(
        [
            "unknown", "unknown artist", "неизвестный исполнитель",
            "неизвестен", "various artists", "va", "разные исполнители"
        ].map { normalized($0) }
    )

    // MARK: - Text

    static func normalized(_ value: String) -> String {
        let folded = value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "ru_RU"))
            .lowercased()
        let allowed = CharacterSet.alphanumerics
        let tokens = folded
            .components(separatedBy: allowed.inverted)
            .filter { !$0.isEmpty }
        return tokens.joined(separator: " ")
    }

    static func comparisonTitle(_ value: String) -> String {
        // Сначала убираем пояснения в скобках, но только если это издание,
        // ремастер или версия. «Song (Live)» остаётся отдельной записью.
        let withoutAnnotations = removeEditionAnnotations(from: value)
        var text = normalized(withoutAnnotations)

        // Издания и ремастеры не должны выглядеть как отдельные композиции.
        let removable = [
            "remastered version", "remastered", "remaster",
            "anniversary edition", "album version", "single version",
            "radio edit", "bonus track", "deluxe", "explicit", "clean",
            "ремастер", "делюкс", "бонус"
        ]
        var removedEditionMarker = false
        for marker in removable where text.contains(marker) {
            removedEditionMarker = true
            text = text.replacingOccurrences(of: marker, with: " ")
        }
        // «Song Remastered 2024» и «Song (2024 Remaster)» — одна композиция.
        if removedEditionMarker {
            text = text.replacingOccurrences(
                of: #"\b(19|20)\d{2}\b"#,
                with: " ",
                options: .regularExpression
            )
        }

        // «feat.» и «при уч.» не меняют саму песню для дедупликации.
        if let range = text.range(of: " feat ") {
            text = String(text[..<range.lowerBound])
        }
        if let range = text.range(of: " при уч ") {
            text = String(text[..<range.lowerBound])
        }
        return text
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func removeEditionAnnotations(from value: String) -> String {
        let markers = [
            "remaster", "deluxe", "explicit", "clean",
            "album version", "single version", "radio edit",
            "bonus", "anniversary edition", "feat", "при уч",
            "ремастер", "делюкс", "бонус"
        ]
        guard let regex = try? NSRegularExpression(
            pattern: #"[\(\[\{][^\)\]\}]*[\)\]\}]"#
        ) else {
            return value
        }

        let nsValue = value as NSString
        let result = NSMutableString(string: value)
        let matches = regex.matches(
            in: value,
            range: NSRange(location: 0, length: nsValue.length)
        )
        for match in matches.reversed() {
            let segment = nsValue.substring(with: match.range).lowercased()
            if markers.contains(where: { segment.contains($0) }) {
                result.replaceCharacters(in: match.range, with: " ")
            }
        }
        return result as String
    }

    static func dedupKey(for track: Track) -> String {
        let artist = normalized(track.artist)
        let title = comparisonTitle(track.title)
        guard !artist.isEmpty, !title.isEmpty else { return track.id }
        return "\(artist)|\(title)"
    }

    static func albumKey(artist: String, title: String) -> String {
        "\(normalized(artist))|\(comparisonTitle(title))"
    }

    static func artistKey(_ name: String) -> String {
        normalized(name)
    }

    // MARK: - Validation

    /// Мягкий фильтр: запись имеет нормальные метаданные и не является явным мусором.
    /// Не требует обложки, лицензии или воспроизводимого потока, чтобы можно было
    /// честно показывать найденные записи и расширять каталог.
    static func isDisplayable(_ track: Track) -> Bool {
        guard !track.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !track.artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        guard !isUnknownArtist(track.artist), !isNoise(track) else { return false }
        if let duration = track.duration, duration > 0 {
            guard duration >= 20, duration <= 3_600 else { return false }
        }
        return true
    }

    /// Есть разрешённый полноценный воспроизводимый поток и валидные метаданные/длительность.
    /// Preview/короткие/неразрешённые записи сюда не попадают.
    static func isPlayableCatalogItem(_ track: Track) -> Bool {
        guard isDisplayable(track) else { return false }
        guard track.isStreamAllowed, !track.playableStreams.isEmpty else { return false }
        guard let duration = track.duration, duration >= 60, duration <= 1_800 else { return false }
        guard !isLikelyPreview(track) else { return false }
        return true
    }

    /// Строгий фильтр для редакционных подборок главной.
    static func isFeatured(_ track: Track) -> Bool {
        guard isPlayableCatalogItem(track) else { return false }
        guard track.license.isKnownOpenLicense else { return false }
        guard track.artworkURL != nil else { return false }
        guard let album = track.album, !album.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        guard !isCoverLike(title: track.title, album: track.album) else { return false }
        return true
    }

    /// Эвристика preview/сэмпла: короткие записи или явно помеченные источники.
    static func isLikelyPreview(_ track: Track) -> Bool {
        if let duration = track.duration, duration > 0, duration < 60 { return true }
        let title = track.title.lowercased()
        if title.contains("preview") || title.contains("sample") || title.contains("snippet") {
            return true
        }
        return false
    }

    static func isNoise(_ track: Track) -> Bool {
        let title = normalized(track.title)
        let album = normalized(track.album ?? "")
        let rawTitle = track.title.lowercased()

        guard !title.isEmpty else { return true }
        guard !title.contains("http"), !rawTitle.contains("www.") else { return true }
        let fileExtensions = [".mp3", ".wav", ".m4a", ".ogg", ".flac", ".aac", ".opus"]
        if fileExtensions.contains(where: { rawTitle.contains($0) }) { return true }

        if noisyPhrases.contains(where: { title.contains($0) }) { return true }

        let titleTokens = Set(title.split(separator: " ").map(String.init))
        if !titleTokens.isDisjoint(with: noiseTokens) { return true }

        if title.hasPrefix("track ") {
            let suffix = title.dropFirst("track ".count)
            if !suffix.isEmpty, suffix.allSatisfy(\.isNumber) { return true }
        }
        if title.allSatisfy(\.isNumber) { return true }

        let albumTokens = Set(album.split(separator: " ").map(String.init))
        if !albumTokens.isDisjoint(with: ["podcast", "подкаст", "audiobook", "аудиокнига"]) {
            return true
        }
        if rawTitle.contains("кавер-версия") || rawTitle.contains("cover version") {
            return true
        }
        return false
    }

    /// Каверы и трибьюты допустимы в поиске, но не должны попадать в
    /// редакционные подборки как «оригинальные релизы». При этом обычная
    /// песня с названием вроде «Cover Me» не считается кавером.
    static func isCoverLike(title: String, album: String?) -> Bool {
        let normalizedTitle = normalized(title)
        let normalizedAlbum = normalized(album ?? "")
        let tokens = Set(normalizedTitle.split(separator: " ").map(String.init))

        if !tokens.isDisjoint(with: ["кавер", "tribute", "трибьют"]) { return true }
        if normalizedAlbum.contains("cover album")
            || normalizedAlbum.contains("cover version")
            || normalizedAlbum.contains("cover songs")
            || normalizedAlbum.contains("кавер") {
            return true
        }
        guard !tokens.isDisjoint(with: coverTokens) else { return false }

        if normalizedTitle == "cover" { return true }
        if normalizedTitle.contains("cover version") || normalizedTitle.contains("cover album") {
            return true
        }
        let raw = title.lowercased()
        if raw.contains("(cover") || raw.contains("[cover") || raw.contains("cover)") || raw.contains("cover]") {
            return true
        }
        // «Cover Me», «Under Cover» и подобные названия — не кавер-версии.
        return false
    }

    static func isUnknownArtist(_ artist: String) -> Bool {
        unknownArtists.contains(normalized(artist))
    }

    // MARK: - Ranking

    static func score(_ track: Track) -> Double {
        var score = 0.0
        if !track.playableStreams.isEmpty { score += 50 }
        if track.license.isKnownOpenLicense { score += 20 }
        if track.artworkURL != nil { score += 12 }
        if track.album?.isEmpty == false { score += 8 }
        if let duration = track.duration, duration >= 90 { score += 4 }
        if track.isRussian { score += 8 }

        if let release = track.releaseDate {
            let age = max(0, Date().timeIntervalSince(release))
            let years = age / (365.25 * 24 * 60 * 60)
            if years < 1 {
                score += 16
            } else if years < 3 {
                score += 10
            } else if years < 8 {
                score += 5
            }
        }
        return score
    }

    static func isNew(_ track: Track, withinYears years: Double = 2) -> Bool {
        guard let release = track.releaseDate else { return false }
        let age = Date().timeIntervalSince(release)
        return age >= -86_400 && age <= years * 365.25 * 24 * 60 * 60
    }
}
