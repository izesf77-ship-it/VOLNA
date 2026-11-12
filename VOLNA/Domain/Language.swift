import Foundation

enum LanguageDetector {
    /// Приводит коды языков разных каталогов к ISO 639-1.
    static func normalize(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let value = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
        guard !value.isEmpty else { return nil }

        if value == "ru" || value.hasPrefix("ru-") || value.contains("russian") || value.contains("русск") {
            return "ru"
        }
        if value == "en" || value.hasPrefix("en-") || value.contains("english") {
            return "en"
        }
        if value == "uk" || value.contains("ukrainian") || value.contains("украин") {
            return "uk"
        }
        if value == "be" || value.contains("belarusian") || value.contains("беларус") {
            return "be"
        }
        if value == "kk" || value.contains("kazakh") || value.contains("казах") {
            return "kk"
        }

        // ISO 639-2/3, которые встречаются в Internet Archive и других архивах.
        let threeLetterCodes: [String: String] = [
            "rus": "ru", "eng": "en", "ukr": "uk", "bel": "be", "kaz": "kk",
            "deu": "de", "ger": "de", "fra": "fr", "fre": "fr", "spa": "es",
            "ita": "it", "pol": "pl", "por": "pt", "nld": "nl", "dut": "nl",
            "swe": "sv", "nor": "no", "fin": "fi", "dan": "da", "tur": "tr",
            "jpn": "ja", "kor": "ko", "zho": "zh", "chi": "zh", "heb": "he",
            "ell": "el", "gre": "el", "ces": "cs", "cze": "cs", "hun": "hu"
        ]
        if let mapped = threeLetterCodes[value] {
            return mapped
        }
        if value.count == 2 {
            return value
        }
        return nil
    }

    static func isCyrillic(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }
        var cyrillic = 0
        var letters = 0
        for scalar in text.unicodeScalars {
            if CharacterSet.letters.contains(scalar) {
                letters += 1
                if (0x0400...0x052F).contains(scalar.value) {
                    cyrillic += 1
                }
            }
        }
        guard letters > 0 else { return false }
        return cyrillic >= 2 || Double(cyrillic) / Double(letters) >= 0.25
    }

    static func detect(declared: String?, texts: [String?]) -> String? {
        if let normalized = normalize(declared) {
            return normalized
        }
        let joined = texts.compactMap { $0 }.joined(separator: " ")
        if isCyrillic(joined) {
            return "ru"
        }
        return nil
    }
}

enum RussianText {
    private static let transliterationMap: [Character: String] = [
        "а": "a", "б": "b", "в": "v", "г": "g", "д": "d", "е": "e", "ё": "e",
        "ж": "zh", "з": "z", "и": "i", "й": "y", "к": "k", "л": "l", "м": "m",
        "н": "n", "о": "o", "п": "p", "р": "r", "с": "s", "т": "t", "у": "u",
        "ф": "f", "х": "kh", "ц": "ts", "ч": "ch", "ш": "sh", "щ": "shch",
        "ъ": "", "ы": "y", "ь": "", "э": "e", "ю": "yu", "я": "ya",
        "і": "i", "ї": "yi", "є": "ye", "ґ": "g", "ў": "u"
    ]

    static func hasCyrillic(_ text: String) -> Bool {
        LanguageDetector.isCyrillic(text)
    }

    static func transliterate(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        for character in text {
            let lower = Character(String(character).lowercased())
            if let replacement = transliterationMap[lower] {
                if character.isUppercase {
                    result.append(replacement.prefix(1).uppercased() + replacement.dropFirst())
                } else {
                    result.append(replacement)
                }
            } else {
                result.append(character)
            }
        }
        return result
    }

    /// Варианты запроса для каталогов, где встречаются и кириллица, и латиница.
    static func queryVariants(_ query: String) -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        var result = [trimmed]
        if hasCyrillic(trimmed) {
            let transliterated = transliterate(trimmed)
            if transliterated.caseInsensitiveCompare(trimmed) != .orderedSame,
               !transliterated.isEmpty {
                result.append(transliterated)
            }
        }
        return result
    }

    static func normalizedKey(_ text: String) -> String {
        let transliterated = transliterate(text)
            .lowercased()
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        let allowed = CharacterSet.alphanumerics.union(CharacterSet.whitespaces)
        let cleaned = transliterated.unicodeScalars.map { scalar -> Character in
            allowed.contains(scalar) ? Character(scalar) : " "
        }
        return String(cleaned)
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    /// Убирает служебные пометки, которые часто мешают дедупликации.
    static func comparisonTitle(_ title: String) -> String {
        var value = title
        if let regex = try? NSRegularExpression(pattern: #"\s*[\(\[\{].*?[\)\]\}]"#) {
            let range = NSRange(value.startIndex..., in: value)
            value = regex.stringByReplacingMatches(in: value, range: range, withTemplate: " ")
        }
        let noise = [
            "official audio", "official video", "lyrics", "lyric video", "remastered",
            "remaster", "radio edit", "album version", "single version", "bonus track",
            "оригинал", "премьера", "клип", "минус", "cover"
        ]
        var normalized = value.lowercased()
        for word in noise {
            normalized = normalized.replacingOccurrences(of: word, with: " ")
        }
        return normalizedKey(normalized)
    }
}
