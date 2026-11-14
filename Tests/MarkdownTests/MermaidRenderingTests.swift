import XCTest
import WebKit

/// Loads the real renderer bundle in a web view, so the CSP, the scheme handler
/// and the vendored Mermaid bundle are all exercised together.
@MainActor
final class MermaidRenderingTests: XCTestCase {
    /// Loads the renderer and waits for the same `rendererReady` message the app waits for.
    /// Everything the page reports is kept, so a failed load can say why.
    private final class RendererSession: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        private static let errorCapture = """
        window.addEventListener('error', event => {
            const target = event.target && event.target.src ? ' (' + event.target.src + ')' : '';
            window.webkit.messageHandlers.logger.postMessage('PAGE ERROR: ' + event.message + target);
        }, true);
        """

        let webView: WKWebView
        private(set) var log: [String] = []
        private var ready: CheckedContinuation<Void, Error>?
        private var isReady = false

        init(rendererRoot: URL) {
            let configuration = WKWebViewConfiguration()
            configuration.setURLSchemeHandler(
                RendererBundleSchemeHandler(rootDirectory: rendererRoot),
                forURLScheme: RendererBundleSchemeHandler.scheme
            )
            webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 900, height: 700), configuration: configuration)
            super.init()
            configuration.userContentController.add(self, name: "logger")
            configuration.userContentController.addUserScript(
                WKUserScript(source: Self.errorCapture, injectionTime: .atDocumentStart, forMainFrameOnly: true)
            )
            webView.navigationDelegate = self
        }

        func start() async throws {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask { @MainActor in
                    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                        self.ready = continuation
                        self.webView.load(URLRequest(url: RendererBundleSchemeHandler.rendererURL()))
                    }
                }
                group.addTask { @MainActor in
                    try await Task.sleep(nanoseconds: 20_000_000_000)
                    throw NSError(domain: "MermaidRenderingTests", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: "Renderer did not report ready. Page log:\n" + self.log.joined(separator: "\n"),
                    ])
                }
                try await group.next()
                group.cancelAll()
            }
        }

        private func finish(_ result: Result<Void, Error>) {
            guard let ready else { return }
            self.ready = nil
            ready.resume(with: result)
        }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            let text = String(describing: message.body)
            log.append(text)
            if text == "rendererReady" { isReady = true; finish(.success(())) }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            finish(.failure(error))
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            finish(.failure(error))
        }
    }

    private struct Outcome: Decodable {
        let diagrams: Int
        let svgs: Int
        let codeBlocks: Int
        let errorNotes: Int
        let mermaidLoaded: Bool
    }

    /// Held for the whole test: a local would be released after its last use, mid-await.
    private var session: RendererSession?

    private func rendererRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Renderer", isDirectory: true)
    }

    /// Renders `html` through `window.renderMarkdown` and reports what ended up in the page.
    private func render(html: String) async throws -> Outcome {
        let session = RendererSession(rendererRoot: rendererRoot())
        self.session = session
        try await session.start()

        let script = """
        await window.renderMarkdown('', { html, theme: 'default', enableKatex: false });
        const root = document.getElementById('markdown-preview');
        return JSON.stringify({
            diagrams: root.querySelectorAll('.boa-diagram').length,
            svgs: root.querySelectorAll('.boa-diagram svg').length,
            codeBlocks: root.querySelectorAll('pre > code.language-mermaid').length,
            errorNotes: root.querySelectorAll('.mermaid-error-note').length,
            mermaidLoaded: typeof window.mermaid !== 'undefined',
        });
        """
        let result = try await session.webView.callAsyncJavaScript(script, arguments: ["html": html], in: nil, contentWorld: .page)
        let json = try XCTUnwrap(result as? String)
        return try JSONDecoder().decode(Outcome.self, from: Data(json.utf8))
    }

    func testFlowchartBlockBecomesSVGDiagram() async throws {
        let outcome = try await render(html: "<pre><code class=\"language-mermaid\">graph TD\n  A[Start] --> B[End]\n</code></pre>")

        XCTAssertEqual(outcome.diagrams, 1)
        XCTAssertEqual(outcome.svgs, 1)
        XCTAssertEqual(outcome.codeBlocks, 0)
        XCTAssertEqual(outcome.errorNotes, 0)
    }

    func testSequenceDiagramRenders() async throws {
        let outcome = try await render(html: "<pre><code class=\"language-mermaid\">sequenceDiagram\n  Alice->>Bob: Hello\n  Bob-->>Alice: Hi\n</code></pre>")

        XCTAssertEqual(outcome.svgs, 1)
        XCTAssertEqual(outcome.errorNotes, 0)
    }

    func testInvalidDiagramStaysAsCodeWithANote() async throws {
        let outcome = try await render(html: "<pre><code class=\"language-mermaid\">this is not a diagram ???</code></pre>")

        XCTAssertEqual(outcome.diagrams, 0)
        XCTAssertEqual(outcome.codeBlocks, 1)
        XCTAssertEqual(outcome.errorNotes, 1)
    }

    func testThemeSwitchRedrawsTheDiagram() async throws {
        let session = RendererSession(rendererRoot: rendererRoot())
        self.session = session
        try await session.start()

        let script = """
        await window.renderMarkdown('', { html, theme: 'default', enableKatex: false });
        const read = () => document.querySelector('.boa-diagram-viewport')?.innerHTML ?? '';
        const light = read();
        window.updateTheme('dark');
        for (let i = 0; i < 100 && read() === light; i++) await new Promise(resolve => setTimeout(resolve, 50));
        return JSON.stringify({ changed: read() !== light, diagrams: document.querySelectorAll('.boa-diagram').length });
        """
        let html = "<pre><code class=\"language-mermaid\">graph TD\n  A[Start] --> B[End]\n</code></pre>"
        let result = try await session.webView.callAsyncJavaScript(script, arguments: ["html": html], in: nil, contentWorld: .page)
        let json = try XCTUnwrap(result as? String)
        let outcome = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])

        XCTAssertEqual(outcome["diagrams"] as? Int, 1)
        XCTAssertEqual(outcome["changed"] as? Bool, true, "The diagram should be redrawn with the dark theme")
    }

    func testDocumentWithoutDiagramsNeverLoadsMermaid() async throws {
        let outcome = try await render(html: "<p>Plain text</p><pre><code class=\"language-swift\">let x = 1</code></pre>")

        XCTAssertFalse(outcome.mermaidLoaded)
        XCTAssertEqual(outcome.diagrams, 0)
    }
}
