import XCTest
@testable import VOLNA

final class LanguageTests: XCTestCase {
    func testTransliteration() {
        XCTAssertEqual(RussianText.transliterate("Кино"), "Kino")
        XCTAssertEqual(RussianText.transliterate("Ёлка"), "Elka")
        XCTAssertEqual(RussianText.transliterate("Щука"), "Shchuka")
        XCTAssertEqual(RussianText.transliterate("Hello"), "Hello")
    }

    func testQueryVariants() {
        let variants = RussianText.queryVariants("Кино")
        XCTAssertEqual(variants.first, "Кино")
        XCTAssertTrue(variants.contains("Kino"))

        XCTAssertEqual(RussianText.queryVariants("Kino"), ["Kino"])
        XCTAssertTrue(RussianText.queryVariants("   ").isEmpty)
    }

    func testNormalizedKey() {
        XCTAssertEqual(RussianText.normalizedKey("Ёлка — Песня"), "elka pesnya")
        XCTAssertEqual(RussianText.normalizedKey("Kino"), "kino")
        XCTAssertEqual(
            RussianText.normalizedKey("Кино"),
            RussianText.normalizedKey("Kino")
        )
    }

    func testComparisonTitleRemovesNoise() {
        XCTAssertEqual(RussianText.comparisonTitle("Song (Official Audio)"), "song")
        XCTAssertEqual(RussianText.comparisonTitle("Track [Remastered 2011]"), "track")
        XCTAssertEqual(RussianText.comparisonTitle("Песня (клип)"), "pesnya")
    }

    func testCyrillicDetection() {
        XCTAssertTrue(LanguageDetector.isCyrillic("Привет"))
        XCTAssertTrue(LanguageDetector.isCyrillic("Кино"))
        XCTAssertFalse(LanguageDetector.isCyrillic("Hello world"))
        XCTAssertFalse(LanguageDetector.isCyrillic(""))
    }

    func testLanguageNormalization() {
        XCTAssertEqual(LanguageDetector.normalize("russian"), "ru")
        XCTAssertEqual(LanguageDetector.normalize("rus"), "ru")
        XCTAssertEqual(LanguageDetector.normalize("eng"), "en")
        XCTAssertEqual(LanguageDetector.normalize("ru-RU"), "ru")
        XCTAssertEqual(LanguageDetector.normalize("deu"), "de")
        XCTAssertNil(LanguageDetector.normalize(nil))
    }

    func testDetectFromText() {
        XCTAssertEqual(LanguageDetector.detect(declared: nil, texts: ["Кино", "Группа"]), "ru")
        XCTAssertNil(LanguageDetector.detect(declared: nil, texts: ["Kino", "Band"]))
        XCTAssertEqual(LanguageDetector.detect(declared: "rus", texts: ["Kino"]), "ru")
    }
}
