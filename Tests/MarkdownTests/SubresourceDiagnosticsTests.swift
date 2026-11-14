import XCTest
import WebKit

final class SubresourceDiagnosticsTests: XCTestCase {
    private func defaults(withValue value: Bool) -> UserDefaults {
        let suite = "SubresourceDiagnosticsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set(value, forKey: SubresourceDiagnostics.defaultsKey)
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return defaults
    }

    func testEnvironmentVariableEnablesDiagnostics() {
        XCTAssertTrue(SubresourceDiagnostics.isEnabled(environment: [SubresourceDiagnostics.environmentKey: "1"],
                                                       defaults: defaults(withValue: false)))
    }

    func testEnvironmentVariableOverridesDefaults() {
        for value in ["0", "false", "no", "off", "  ", ""] {
            XCTAssertFalse(SubresourceDiagnostics.isEnabled(environment: [SubresourceDiagnostics.environmentKey: value],
                                                            defaults: defaults(withValue: true)),
                           "expected \(value.isEmpty ? "<empty>" : value) to disable diagnostics")
        }
    }

    func testFallsBackToUserDefaultsWhenEnvironmentIsAbsent() {
        XCTAssertTrue(SubresourceDiagnostics.isEnabled(environment: [:], defaults: defaults(withValue: true)))
        XCTAssertFalse(SubresourceDiagnostics.isEnabled(environment: [:], defaults: defaults(withValue: false)))
    }

    func testUserScriptPostsToTheRegisteredHandlerName() {
        XCTAssertTrue(SubresourceDiagnostics.source.contains(SubresourceDiagnostics.messageHandlerName))
        XCTAssertTrue(SubresourceDiagnostics.source.contains("__boaSubresourceDiagnostics"))
    }

    func testUserScriptRunsOnceInTheMainFrameBeforeResourcesLoad() {
        let script = SubresourceDiagnostics.userScript()

        XCTAssertEqual(script.source, SubresourceDiagnostics.source)
        XCTAssertEqual(script.injectionTime, .atDocumentStart)
        XCTAssertTrue(script.isForMainFrameOnly)
    }

    func testFailedURLsReadsDictionaryPayload() {
        let failures = SubresourceDiagnostics.failedURLs(from: ["url": "file:///tmp/missing.png", "tag": "IMG"])

        XCTAssertEqual(failures.count, 1)
        XCTAssertEqual(failures.first?.url, "file:///tmp/missing.png")
        XCTAssertEqual(failures.first?.tag, "IMG")
    }

    func testFailedURLsReadsJSONStringPayload() {
        let failures = SubresourceDiagnostics.failedURLs(from: "{\"url\":\"boa-renderer://bundle/vendor/katex/katex.woff\",\"tag\":\"LINK\"}")

        XCTAssertEqual(failures.count, 1)
        XCTAssertEqual(failures.first?.url, "boa-renderer://bundle/vendor/katex/katex.woff")
        XCTAssertEqual(failures.first?.tag, "LINK")
    }

    func testFailedURLsTreatsPlainTextPayloadAsURL() {
        let failures = SubresourceDiagnostics.failedURLs(from: "file:///tmp/gone.gif")

        XCTAssertEqual(failures.count, 1)
        XCTAssertEqual(failures.first?.url, "file:///tmp/gone.gif")
        XCTAssertEqual(failures.first?.tag, "")
    }

    func testFailedURLsIgnoresPayloadsWithoutURL() {
        XCTAssertTrue(SubresourceDiagnostics.failedURLs(from: ["tag": "IMG"]).isEmpty)
        XCTAssertTrue(SubresourceDiagnostics.failedURLs(from: [String: Any]()).isEmpty)
        XCTAssertTrue(SubresourceDiagnostics.failedURLs(from: "").isEmpty)
        XCTAssertTrue(SubresourceDiagnostics.failedURLs(from: nil).isEmpty)
    }

    func testSanitizedFlattensControlCharactersAndCollapsesWhitespace() {
        let sanitized = SubresourceDiagnostics.sanitized("file:///tmp/a\n\nb\r\nc\u{7}d")

        XCTAssertEqual(sanitized, "file:///tmp/a b c d")
    }

    func testSanitizedBoundsLengthOfPageSuppliedText() {
        let sanitized = SubresourceDiagnostics.sanitized(String(repeating: "a", count: SubresourceDiagnostics.loggedCharacterLimit + 50))

        XCTAssertEqual(sanitized.count, SubresourceDiagnostics.loggedCharacterLimit + 1)
        XCTAssertTrue(sanitized.hasSuffix("…"))
    }
}
