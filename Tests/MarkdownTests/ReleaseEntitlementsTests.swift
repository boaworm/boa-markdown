import XCTest

final class ReleaseEntitlementsTests: XCTestCase {
    func testProjectUsesReleaseSpecificEntitlements() throws {
        let project = try String(
            contentsOf: projectRoot().appendingPathComponent("project.yml"),
            encoding: .utf8
        )

        XCTAssertTrue(project.contains("CODE_SIGN_ENTITLEMENTS: Sources/Markdown/MarkdownRelease.entitlements"))
        XCTAssertTrue(
            project.contains("CODE_SIGN_INJECT_BASE_ENTITLEMENTS: NO"),
            "The app Release configuration must disable Xcode's base entitlement injection."
        )
    }

    func testProjectEnablesTheHardenedRuntime() throws {
        let project = try String(contentsOf: projectRoot().appendingPathComponent("project.yml"), encoding: .utf8)
        XCTAssertTrue(project.contains("ENABLE_HARDENED_RUNTIME: YES"))
    }

    func testReleaseEntitlementsDropTheDebugger() throws {
        let appRelease = try String(
            contentsOf: projectRoot().appendingPathComponent("Sources/Markdown/MarkdownRelease.entitlements"),
            encoding: .utf8
        )

        XCTAssertFalse(appRelease.contains("com.apple.security.get-task-allow"))
    }

    func testBothEntitlementFilesEnableTheSandboxAndLetTheWebViewStart() throws {
        for name in ["Markdown.entitlements", "MarkdownRelease.entitlements"] {
            let url = projectRoot().appendingPathComponent("Sources/Markdown/\(name)")
            let plist = try XCTUnwrap(
                PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any],
                "\(name) must be a property list"
            )

            XCTAssertEqual(plist["com.apple.security.app-sandbox"] as? Bool, true, "\(name) must enable the App Sandbox")
            XCTAssertEqual(plist["com.apple.security.files.user-selected.read-write"] as? Bool, true,
                           "\(name) must let the save panel write exports")
            XCTAssertEqual(plist["com.apple.security.files.bookmarks.app-scope"] as? Bool, true,
                           "\(name) must allow bookmarks so folder grants survive a relaunch")
            XCTAssertNil(plist["com.apple.security.files.user-selected.read-only"],
                         "\(name) must not keep the read-only entitlement next to read-write")
            // WKWebView's web content and GPU processes do not launch inside the sandbox without this,
            // and the page stays blank. Incoming connections are never needed.
            XCTAssertEqual(plist["com.apple.security.network.client"] as? Bool, true,
                           "\(name) must keep network.client or the web view cannot start")
            XCTAssertNil(plist["com.apple.security.network.server"], "\(name) must not request incoming network access")
            // JavaScript is compiled in WebKit's own web content process, not in the app.
            XCTAssertNil(plist["com.apple.security.cs.allow-jit"], "\(name) must not let the app process map JIT memory")
        }
    }

    private func projectRoot() -> URL {
        URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
