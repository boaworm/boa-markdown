import XCTest

final class DisplayVersionTests: XCTestCase {

    func testDisplayVersionUsesDevelopmentOverrideWhenPresent() {
        let info: [String: Any] = [
            "CFBundleShortVersionString": "1.32.427",
            "BoaDisplayVersion": "1.32.427-dev-20260521-1430"
        ]

        XCTAssertEqual(
            DisplayVersion.text(from: info),
            "1.32.427-dev-20260521-1430"
        )
    }

    func testDisplayVersionFallsBackToBundleShortVersion() {
        let info: [String: Any] = [
            "CFBundleShortVersionString": "1.32.427"
        ]

        XCTAssertEqual(DisplayVersion.text(from: info), "1.32.427")
    }

    func testDisplayVersionIgnoresEmptyDevelopmentOverride() {
        let info: [String: Any] = [
            "CFBundleShortVersionString": "1.32.427",
            "BoaDisplayVersion": "   "
        ]

        XCTAssertEqual(DisplayVersion.text(from: info), "1.32.427")
    }

    func testDisplayVersionReturnsNilWhenNoVersionExists() {
        XCTAssertNil(DisplayVersion.text(from: [:]))
    }
}
