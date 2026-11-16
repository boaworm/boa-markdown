import WebKit
import XCTest

final class RendererNavigationPolicyTests: XCTestCase {
    func testOnlyTheBundledRendererMayLoad() {
        XCTAssertEqual(RendererNavigationPolicy.decision(for: RendererBundleSchemeHandler.rendererURL(), isLinkActivated: false), .allow)
        XCTAssertEqual(RendererNavigationPolicy.decision(for: URL(string: "boa-renderer://bundle/index.html#section"), isLinkActivated: true), .allow)
        XCTAssertEqual(RendererNavigationPolicy.decision(for: URL(string: "boa-renderer://elsewhere/index.html"), isLinkActivated: false), .cancel)
    }

    func testRemotePagesNeverLoadInTheWebView() {
        for text in ["https://example.com/?q=secret", "http://example.com", "ftp://example.com/a", "data:text/html,<p>x</p>",
                     "file:///etc/passwd", "about:blank", "javascript:alert(1)", "local-md://x/a.png"] {
            XCTAssertEqual(RendererNavigationPolicy.decision(for: URL(string: text), isLinkActivated: false), .cancel, text)
        }
        XCTAssertEqual(RendererNavigationPolicy.decision(for: nil, isLinkActivated: true), .cancel)
    }

    func testAClickedWebLinkGoesToTheBrowser() throws {
        let url = try XCTUnwrap(URL(string: "HTTPS://example.com/page"))
        XCTAssertEqual(RendererNavigationPolicy.decision(for: url, isLinkActivated: true), .openInBrowser(url))
        XCTAssertEqual(RendererNavigationPolicy.decision(for: URL(string: "mailto:a@example.com"), isLinkActivated: true), .cancel)
    }

    func testBlocklistIsValidContentRuleJSON() throws {
        let rules = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(RendererNetworkBlocklist.encodedRules.utf8)) as? [[String: [String: String]]])
        XCTAssertEqual(rules.compactMap { $0["trigger"]?["url-filter"] }.sorted(), RendererNetworkBlocklist.blockedURLFilters.sorted())
        XCTAssertTrue(rules.allSatisfy { $0["action"]?["type"] == "block" })
    }

    @MainActor func testBlocklistCompiles() {
        let compiled = expectation(description: "rule list compiled")
        WKContentRuleListStore.default().compileContentRuleList(forIdentifier: RendererNetworkBlocklist.identifier + ".test",
                                                                encodedContentRuleList: RendererNetworkBlocklist.encodedRules) { list, error in
            XCTAssertNotNil(list, error?.localizedDescription ?? "")
            compiled.fulfill()
        }
        wait(for: [compiled], timeout: 10)
    }
}
