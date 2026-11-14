import XCTest

final class RendererBundleSchemeHandlerTests: XCTestCase {
    func testRendererURLUsesCustomSchemeOrigin() {
        let url = RendererBundleSchemeHandler.rendererURL()

        XCTAssertEqual(url.scheme, "boa-renderer")
        XCTAssertEqual(url.host, "bundle")
        XCTAssertEqual(url.path, "/index.html")
    }

    func testResolveContainedFileURLAllowsNestedBundleAsset() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let assets = root.appendingPathComponent("assets", isDirectory: true)
        try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let jsURL = assets.appendingPathComponent("main.js")
        try "console.log('ok')".write(to: jsURL, atomically: true, encoding: .utf8)

        let handler = RendererBundleSchemeHandler(rootDirectory: root)
        let requestedURL = URL(string: "boa-renderer://bundle/assets/main.js")!

        let resolved = try XCTUnwrap(handler.resolveContainedFileURL(from: requestedURL))
        XCTAssertEqual(resolved.standardizedFileURL.path, jsURL.standardizedFileURL.path)
    }

    func testResolveContainedFileURLRejectsParentTraversal() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let assets = root.appendingPathComponent("assets", isDirectory: true)
        try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let handler = RendererBundleSchemeHandler(rootDirectory: assets)
        let requestedURL = URL(string: "boa-renderer://bundle/%2e%2e/index.html")!

        XCTAssertNil(handler.resolveContainedFileURL(from: requestedURL))
    }

    func testBuildResponseSetsJavaScriptMimeType() {
        let root = URL(fileURLWithPath: "/tmp/WebRenderer", isDirectory: true)
        let handler = RendererBundleSchemeHandler(rootDirectory: root)
        let requestURL = URL(string: "boa-renderer://bundle/assets/main.js")!
        let fileURL = root.appendingPathComponent("assets/main.js")
        let response = handler.buildResponse(for: requestURL, fileURL: fileURL, data: Data())

        XCTAssertEqual((response as? HTTPURLResponse)?.mimeType, "application/javascript")
    }

    func testAppLoadsRendererThroughCustomScheme() throws {
        let root = try projectRoot()
        let mainWebViewSource = try String(
            contentsOf: root.appendingPathComponent("Sources/Markdown/MarkdownWebView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(mainWebViewSource.contains("setURLSchemeHandler(rendererHandler, forURLScheme: RendererBundleSchemeHandler.scheme)"))
        XCTAssertTrue(mainWebViewSource.contains("webView.load(URLRequest(url: url))"))
        XCTAssertFalse(mainWebViewSource.contains("webView.loadFileURL(url, allowingReadAccessTo:"))
    }

    private func projectRoot() throws -> URL {
        URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
