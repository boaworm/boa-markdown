import XCTest
import AppKit
import WebKit

final class RendererExportPreparationTests: XCTestCase {
    func testOnlyKnownPreparationPayloadsAreAccepted() {
        XCTAssertEqual(RendererExportPreparation.decode(["status":"mathematics"]), .mathematics)
        XCTAssertEqual(RendererExportPreparation.decode(["status":"ready", "html":"<p>ok</p>"]), .ready(html: "<p>ok</p>"))
        XCTAssertEqual(RendererExportPreparation.decode(["status":"ready"]), .ready(html: nil))
        XCTAssertNil(RendererExportPreparation.decode(["status":"mathematics", "source":"private"]))
        XCTAssertNil(RendererExportPreparation.decode(["status":"ready", "html":42]))
        XCTAssertNil(RendererExportPreparation.decode(["status":"other"]))
    }
}

extension RendererExportPreparationTests {
    func testNativeWebViewExposesIncidentActionsToAccessibility() throws {
        let webView = NativeMagnifyingWebView(frame: NSRect(x: 0, y: 0, width: 900, height: 700), configuration: WKWebViewConfiguration())
        FailureNotice.attach(to: webView, kind: .exportHTML, recoveryTitle: "Open in External Editor", recovery: {})
        let notice = try XCTUnwrap(webView.subviews.compactMap { $0 as? FailureNotice }.first)
        XCTAssertTrue((webView.accessibilityChildren() ?? []).contains { ($0 as? NSView) === notice })
        XCTAssertEqual(notice.accessibilityRole(), .group)
        notice.removeFromSuperview()
        XCTAssertFalse((webView.accessibilityChildren() ?? []).contains { ($0 as? NSView) === notice })
    }

    func testExportEditorRecoveryTranslationExistsInEveryAppLanguage() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        for language in ["en"] {
            let data = try Data(contentsOf: root.appendingPathComponent("Sources/Markdown/\(language).lproj/Localizable.strings"))
            let strings = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String:String])
            XCTAssertNotNil(strings["Open in External Editor"])
        }
    }
}
