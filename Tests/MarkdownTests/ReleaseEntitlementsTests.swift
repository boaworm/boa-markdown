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

    func testReleaseEntitlementsDropTheDebugger() throws {
        let appRelease = try String(
            contentsOf: projectRoot().appendingPathComponent("Sources/Markdown/MarkdownRelease.entitlements"),
            encoding: .utf8
        )

        XCTAssertFalse(appRelease.contains("com.apple.security.get-task-allow"))
    }

    private func projectRoot() -> URL {
        URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
