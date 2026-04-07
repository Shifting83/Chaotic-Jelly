import XCTest
@testable import ChaoticJelly

final class LanguageUtilsTests: XCTestCase {

    func testRecognizedCodes() {
        XCTAssertTrue(LanguageUtils.isRecognizedCode("eng"))
        XCTAssertTrue(LanguageUtils.isRecognizedCode("en"))
        XCTAssertTrue(LanguageUtils.isRecognizedCode("fre"))
        XCTAssertTrue(LanguageUtils.isRecognizedCode("spa"))
        XCTAssertTrue(LanguageUtils.isRecognizedCode("jpn"))
        XCTAssertTrue(LanguageUtils.isRecognizedCode("und"))

        // Case insensitive
        XCTAssertTrue(LanguageUtils.isRecognizedCode("ENG"))
        XCTAssertTrue(LanguageUtils.isRecognizedCode("Eng"))
    }

    func testUnrecognizedCodes() {
        XCTAssertFalse(LanguageUtils.isRecognizedCode("xyz"))
        XCTAssertFalse(LanguageUtils.isRecognizedCode(""))
        XCTAssertFalse(LanguageUtils.isRecognizedCode("asdf"))
    }

    func testTitleContainsLanguageName() {
        XCTAssertTrue(LanguageUtils.titleContainsLanguageName("English Stereo"))
        XCTAssertTrue(LanguageUtils.titleContainsLanguageName("French 5.1"))
        XCTAssertTrue(LanguageUtils.titleContainsLanguageName("Japanese Commentary"))
        XCTAssertTrue(LanguageUtils.titleContainsLanguageName("GERMAN"))

        XCTAssertFalse(LanguageUtils.titleContainsLanguageName("Stereo"))
        XCTAssertFalse(LanguageUtils.titleContainsLanguageName("5.1 Surround"))
        XCTAssertFalse(LanguageUtils.titleContainsLanguageName(""))
    }

    func testIsEnglish() {
        XCTAssertTrue(LanguageUtils.isEnglish("eng"))
        XCTAssertTrue(LanguageUtils.isEnglish("en"))
        XCTAssertTrue(LanguageUtils.isEnglish("english"))
        XCTAssertTrue(LanguageUtils.isEnglish("ENG"))
        XCTAssertTrue(LanguageUtils.isEnglish("English"))

        XCTAssertFalse(LanguageUtils.isEnglish("fre"))
        XCTAssertFalse(LanguageUtils.isEnglish(nil))
        XCTAssertFalse(LanguageUtils.isEnglish(""))
    }

    func testNormalize() {
        XCTAssertEqual(LanguageUtils.normalize("en"), "eng")
        XCTAssertEqual(LanguageUtils.normalize("fr"), "fre")
        XCTAssertEqual(LanguageUtils.normalize("de"), "ger")
        XCTAssertEqual(LanguageUtils.normalize("es"), "spa")
        XCTAssertEqual(LanguageUtils.normalize("ja"), "jpn")

        // Already 3-letter
        XCTAssertEqual(LanguageUtils.normalize("eng"), "eng")
        XCTAssertEqual(LanguageUtils.normalize("fre"), "fre")

        // Unknown stays as-is
        XCTAssertEqual(LanguageUtils.normalize("xyz"), "xyz")
    }

    func testDisplayName() {
        let engName = LanguageUtils.displayName(for: "eng")
        // Should return something meaningful (exact string depends on locale)
        XCTAssertFalse(engName.isEmpty)
    }
}
