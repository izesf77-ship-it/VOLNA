import XCTest
@testable import VOLNA

final class LicenseTests: XCTestCase {
    func testCreativeCommonsURLs() {
        XCTAssertEqual(
            LicenseParser.parse(urlString: "https://creativecommons.org/licenses/by/4.0/"),
            .ccBy
        )
        XCTAssertEqual(
            LicenseParser.parse(urlString: "https://creativecommons.org/licenses/by-sa/4.0/"),
            .ccBySa
        )
        XCTAssertEqual(
            LicenseParser.parse(urlString: "https://creativecommons.org/licenses/by-nc-sa/4.0/"),
            .ccByNcSa
        )
        XCTAssertEqual(
            LicenseParser.parse(urlString: "https://creativecommons.org/licenses/by-nc-nd/4.0/"),
            .ccByNcNd
        )
        XCTAssertEqual(
            LicenseParser.parse(urlString: "https://creativecommons.org/publicdomain/zero/1.0/"),
            .cc0
        )
        XCTAssertEqual(
            LicenseParser.parse(urlString: "https://creativecommons.org/publicdomain/mark/1.0/"),
            .publicDomain
        )
    }

    func testLicenseNames() {
        XCTAssertEqual(LicenseParser.parse(text: "CC BY 4.0"), .ccBy)
        XCTAssertEqual(LicenseParser.parse(text: "cc-by-sa-4.0"), .ccBySa)
        XCTAssertEqual(LicenseParser.parse(text: "CC BY-NC 4.0"), .ccByNc)
        XCTAssertEqual(LicenseParser.parse(text: "CC0 1.0"), .cc0)
        XCTAssertEqual(LicenseParser.parse(text: "Public domain"), .publicDomain)
    }

    func testRestrictedAndUnknown() {
        XCTAssertEqual(LicenseParser.parse(text: "All rights reserved"), .restricted)
        XCTAssertEqual(LicenseParser.parse(text: nil), .unknown)
        XCTAssertEqual(LicenseParser.parse(urlString: ""), .unknown)
        XCTAssertEqual(LicenseParser.parse(text: "Some custom terms"), .unknown)
        XCTAssertEqual(LicenseParser.parse(text: "GFDL 1.3"), .other)
    }

    func testOpenverseIdentifiers() {
        XCTAssertEqual(LicenseParser.parse(identifier: "by-nc-nd", version: "4.0"), .ccByNcNd)
        XCTAssertEqual(LicenseParser.parse(identifier: "by-sa", version: "4.0"), .ccBySa)
        XCTAssertEqual(LicenseParser.parse(identifier: nil, version: nil), .unknown)
    }

    func testKnownOpenLicenseRequirements() {
        XCTAssertTrue(LicenseType.ccBy.isKnownOpenLicense)
        XCTAssertTrue(LicenseType.ccBy.requiresAttribution)
        XCTAssertFalse(LicenseType.cc0.requiresAttribution)
        XCTAssertFalse(LicenseType.unknown.isKnownOpenLicense)
        XCTAssertFalse(LicenseType.other.isKnownOpenLicense)
        XCTAssertNil(LicenseParser.defaultURL(for: .unknown))
    }
}
