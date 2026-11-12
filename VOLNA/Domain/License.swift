import Foundation

/// Лицензия произведения. Значение `.unknown` означает, что источник не
/// предоставил лицензию — такое произведение нельзя выдавать за свободное.
enum LicenseType: String, Codable, Sendable, CaseIterable, Hashable {
    case cc0 = "CC0"
    case ccBy = "CC-BY"
    case ccBySa = "CC-BY-SA"
    case ccByNd = "CC-BY-ND"
    case ccByNc = "CC-BY-NC"
    case ccByNcSa = "CC-BY-NC-SA"
    case ccByNcNd = "CC-BY-NC-ND"
    case publicDomain = "Public Domain"
    case other = "Other"
    case unknown = "Unknown"
    case restricted = "Restricted"

    var displayName: String {
        switch self {
        case .cc0: return "CC0 / общественное достояние"
        case .ccBy: return "CC BY"
        case .ccBySa: return "CC BY-SA"
        case .ccByNd: return "CC BY-ND"
        case .ccByNc: return "CC BY-NC"
        case .ccByNcSa: return "CC BY-NC-SA"
        case .ccByNcNd: return "CC BY-NC-ND"
        case .publicDomain: return "Общественное достояние"
        case .other: return "Другая лицензия"
        case .unknown: return "Лицензия неизвестна"
        case .restricted: return "Использование ограничено"
        }
    }

    var shortDisplayName: String {
        switch self {
        case .cc0: return "CC0"
        case .ccBy: return "CC BY"
        case .ccBySa: return "CC BY-SA"
        case .ccByNd: return "CC BY-ND"
        case .ccByNc: return "CC BY-NC"
        case .ccByNcSa: return "CC BY-NC-SA"
        case .ccByNcNd: return "CC BY-NC-ND"
        case .publicDomain: return "Public Domain"
        case .other: return "Другая"
        case .unknown: return "Неизвестна"
        case .restricted: return "Ограничена"
        }
    }

    /// Лицензия явно известна и относится к свободным/открытым лицензиям.
    var isKnownOpenLicense: Bool {
        switch self {
        case .cc0, .ccBy, .ccBySa, .ccByNd, .ccByNc, .ccByNcSa, .ccByNcNd, .publicDomain:
            return true
        case .other, .unknown, .restricted:
            return false
        }
    }

    var allowsCommercialUse: Bool {
        switch self {
        case .cc0, .publicDomain, .ccBy, .ccBySa, .ccByNd:
            return true
        case .ccByNc, .ccByNcSa, .ccByNcNd:
            return false
        case .other, .unknown, .restricted:
            return false
        }
    }

    var allowsDerivatives: Bool {
        switch self {
        case .cc0, .publicDomain, .ccBy, .ccBySa, .ccByNc, .ccByNcSa:
            return true
        case .ccByNd, .ccByNcNd:
            return false
        case .other, .unknown, .restricted:
            return false
        }
    }

    var requiresAttribution: Bool {
        switch self {
        case .cc0, .publicDomain:
            return false
        case .ccBy, .ccBySa, .ccByNd, .ccByNc, .ccByNcSa, .ccByNcNd:
            return true
        case .other, .unknown, .restricted:
            return true
        }
    }

    var sortOrder: Int {
        switch self {
        case .cc0: return 0
        case .publicDomain: return 1
        case .ccBy: return 2
        case .ccBySa: return 3
        case .ccByNd: return 4
        case .ccByNc: return 5
        case .ccByNcSa: return 6
        case .ccByNcNd: return 7
        case .other: return 8
        case .unknown: return 9
        case .restricted: return 10
        }
    }
}

enum LicenseParser {
    /// Разбирает URL лицензии, который вернул провайдер.
    static func parse(url: URL?) -> LicenseType {
        parse(urlString: url?.absoluteString)
    }

    static func parse(urlString: String?) -> LicenseType {
        guard let raw = urlString?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return .unknown
        }
        return parse(text: raw)
    }

    /// Разбирает человекочитаемое название лицензии (Wikimedia, ccMixter и т.п.).
    static func parse(text: String?) -> LicenseType {
        guard let source = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !source.isEmpty else {
            return .unknown
        }

        let value = source
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
            .replacingOccurrences(of: " ", with: "-")

        if value.contains("all-rights-reserved") || value.contains("copyright") && !value.contains("creativecommons") {
            return .restricted
        }
        if value.contains("publicdomain/zero") || value.contains("public-domain-zero") || value.contains("cc0") {
            return .cc0
        }
        if value.contains("publicdomain") || value.contains("public-domain") || value.contains("pdm") {
            return .publicDomain
        }

        // Порядок важен: сначала более специфичные варианты.
        if value.contains("by-nc-nd") || value.contains("byncnd") || value.contains("by_nc_nd") {
            return .ccByNcNd
        }
        if value.contains("by-nc-sa") || value.contains("byncsa") || value.contains("by_nc_sa") {
            return .ccByNcSa
        }
        if value.contains("by-nc") || value.contains("bync") || value.contains("by_nc") {
            return .ccByNc
        }
        if value.contains("by-nd") || value.contains("bynd") || value.contains("by_nd") {
            return .ccByNd
        }
        if value.contains("by-sa") || value.contains("bysa") || value.contains("by_sa") {
            return .ccBySa
        }
        if value.contains("cc-by") || value.contains("creativecommons.org/licenses/by") || value == "by" || value.hasPrefix("by-") {
            return .ccBy
        }

        if value.contains("gfdl") || value.contains("fal") || value.contains("art-libre") {
            return .other
        }
        if value.contains("restricted") {
            return .restricted
        }
        // Неизвестный непустой текст нельзя считать ни свободной, ни «другой
        // известной» лицензией. Он остаётся UNKNOWN.
        return .unknown
    }

    /// Нормализует короткое имя лицензии Creative Commons из поля `license`
    /// (например, Openverse возвращает `by-nc-sa`).
    static func parse(identifier: String?, version: String?) -> LicenseType {
        guard let identifier, !identifier.isEmpty else { return .unknown }
        let normalized = identifier.lowercased().replacingOccurrences(of: " ", with: "-")
        switch normalized {
        case "cc0", "zero":
            return .cc0
        case "pdm", "publicdomain":
            return .publicDomain
        case "by":
            return .ccBy
        case "by-sa":
            return .ccBySa
        case "by-nd":
            return .ccByNd
        case "by-nc":
            return .ccByNc
        case "by-nc-sa":
            return .ccByNcSa
        case "by-nc-nd":
            return .ccByNcNd
        default:
            return parse(text: identifier + (version.map { " \($0)" } ?? ""))
        }
    }

    static func defaultURL(for license: LicenseType) -> URL? {
        switch license {
        case .cc0:
            return URL(string: "https://creativecommons.org/publicdomain/zero/1.0/")
        case .ccBy:
            return URL(string: "https://creativecommons.org/licenses/by/4.0/")
        case .ccBySa:
            return URL(string: "https://creativecommons.org/licenses/by-sa/4.0/")
        case .ccByNd:
            return URL(string: "https://creativecommons.org/licenses/by-nd/4.0/")
        case .ccByNc:
            return URL(string: "https://creativecommons.org/licenses/by-nc/4.0/")
        case .ccByNcSa:
            return URL(string: "https://creativecommons.org/licenses/by-nc-sa/4.0/")
        case .ccByNcNd:
            return URL(string: "https://creativecommons.org/licenses/by-nc-nd/4.0/")
        case .publicDomain:
            return URL(string: "https://creativecommons.org/publicdomain/mark/1.0/")
        case .other, .unknown, .restricted:
            return nil
        }
    }
}
