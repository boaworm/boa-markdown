import XCTest
@testable import BoaRender

final class MarkdownRendererTests: XCTestCase {
    private func html(_ source: String) -> String { MarkdownRenderer.render(source).html }

    // MARK: GitHub-flavored Markdown

    func testTableStrikethroughAndTaskList() {
        let out = html("| A | B |\n|---|---|\n| 1 | ~~2~~ |\n\n- [x] done\n- [ ] open\n")
        XCTAssertTrue(out.contains("<table"))
        XCTAssertTrue(out.contains("<del>2</del>"))
        XCTAssertTrue(out.contains("type=\"checkbox\" checked=\"\" disabled=\"\""))
        XCTAssertTrue(out.contains("type=\"checkbox\" disabled=\"\""))
    }

    func testFootnotesAndBareURLAutolink() {
        let out = html("Claim[^1] see https://example.org/x.\n\n[^1]: Source.\n")
        XCTAssertTrue(out.contains("class=\"footnotes\""))
        XCTAssertTrue(out.contains("class=\"footnote-ref\""))
        XCTAssertTrue(out.contains("<a href=\"https://example.org/x\">https://example.org/x</a>"))
    }

    func testFencedCodeCarriesLanguageClass() {
        let out = html("```swift\nlet x = 1 < 2\n```\n")
        XCTAssertTrue(out.contains("<code class=\"language-swift\">let x = 1 &lt; 2\n</code>"))
    }

    // MARK: Untrusted content

    func testRawHTMLIsNeverPassedThrough() {
        let out = html("<script>alert(1)</script>\n\nText <img src=x onerror=alert(1)> more <b>bold</b>.\n")
        XCTAssertFalse(out.contains("<script"))
        XCTAssertFalse(out.contains("<img"))
        XCTAssertFalse(out.contains("onerror"))
        XCTAssertFalse(out.contains("<b>"))
    }

    func testUnsafeLinkSchemesLoseTheirDestination() {
        let out = html("[a](javascript:alert(1)) [b](vbscript:x) [c](data:text/html,<script>1</script>) [d](https://ok.example)")
        XCTAssertFalse(out.contains("javascript:"))
        XCTAssertFalse(out.contains("vbscript:"))
        XCTAssertFalse(out.contains("data:text/html"))
        XCTAssertTrue(out.contains("href=\"https://ok.example\""))
    }

    func testAttributeBreakoutInLinkAndImageIsEscaped() {
        let out = html("[x](https://e.example/\"onmouseover=\"alert(1)) ![a\"b](i.png \"t\\\"x\")")
        XCTAssertFalse(out.contains("\"onmouseover=\""))
        XCTAssertFalse(out.contains("alt=\"a\"b\""))
    }

    func testForgedPlaceholdersInSourceAreInert() {
        let out = html("Real $x$ and forged \u{E000}0\u{E001} \u{E000}7\u{E001}")
        XCTAssertEqual(out.components(separatedBy: "class=\"boa-math-source").count - 1, 1)
        XCTAssertFalse(out.contains("\u{E000}"))
    }

    func testAllowedInlineTagsRenderWithoutAttributes() {
        let out = html("Press <kbd>Cmd</kbd>, H<sub>2</sub>O, x<sup>2</sup><br>next <KBD class=\"k\" onclick=\"x()\">K</KBD> <mark>m</mark>")
        XCTAssertTrue(out.contains("<kbd>Cmd</kbd>"))
        XCTAssertTrue(out.contains("H<sub>2</sub>O"))
        XCTAssertTrue(out.contains("x<sup>2</sup><br />"))
        XCTAssertTrue(out.contains("<kbd>K</kbd>"))
        XCTAssertTrue(out.contains("<mark>m</mark>"))
        XCTAssertFalse(out.contains("onclick"))
        XCTAssertFalse(out.contains("class=\"k\""))
        XCTAssertFalse(out.contains("raw HTML omitted"))
    }

    func testDetailsBlockKeepsStructureAndMarkdownInside() {
        let out = html("<details open onclick=\"x()\">\n<summary>More <b>info</b></summary>\n\nHidden **text**\n\n</details>\n")
        XCTAssertTrue(out.contains("<details>\n<summary>More info</summary>"))
        XCTAssertTrue(out.contains("<strong>text</strong>"))
        XCTAssertTrue(out.contains("</details>"))
        XCTAssertFalse(out.contains("onclick"))
    }

    func testUnknownBlockKeepsItsTextButNotItsTags() {
        let out = html("<div align=\"center\">\n<img src=\"a.png\" width=\"200\">\nCentered & <i>words</i>\n</div>\n\nAfter")
        XCTAssertTrue(out.contains("<p>Centered &amp; words</p>"))
        XCTAssertFalse(out.contains("<div"))
        XCTAssertFalse(out.contains("<img"))
        XCTAssertTrue(out.contains("After"))
    }

    func testScriptStyleAndCommentContentIsSwallowed() {
        let out = html("<script>\nalert('block')\n</script>\n\n<style>p{color:red}</style>\n\nInline <script>alert('inline')</script> end.\n\n<!-- note -->\n\nShown <!-- hidden --> text")
        XCTAssertFalse(out.contains("alert"))
        XCTAssertFalse(out.contains("color:red"))
        XCTAssertFalse(out.contains("note"))
        XCTAssertFalse(out.contains("hidden"))
        XCTAssertTrue(out.contains("Inline  end."))
        XCTAssertTrue(out.contains("Shown  text"))
    }

    func testMalformedTagsCannotSmuggleMarkup() {
        for source in ["<kbd/onclick=x>k</kbd>", "<br<script>>", "<<kbd>>", "<details><script>x</script", "<sub\nonclick=x>s</sub>", "<img src=x onerror=alert(1)//"] {
            let out = html(source).lowercased()
            XCTAssertNil(out.range(of: #"<[a-z][^>]*\son[a-z]+\s*="#, options: .regularExpression), source)
            XCTAssertFalse(out.contains("<script"), source)
            XCTAssertFalse(out.contains("<img"), source)
        }
    }

    // MARK: Headings

    func testHeadingsGetUniqueGitHubStyleIDs() {
        let doc = MarkdownRenderer.render("# Hello, World!\n\n## Setup\n\n## Setup\n\n### `code` & more\n")
        XCTAssertEqual(doc.headings.map(\.id), ["hello-world", "setup", "setup-1", "code--more"])
        XCTAssertEqual(doc.headings.map(\.level), [1, 2, 2, 3])
        XCTAssertEqual(doc.headings.map(\.line), [1, 3, 5, 7])
        XCTAssertEqual(doc.headings[3].title, "code & more")
        XCTAssertTrue(doc.html.contains("<h2 id=\"setup-1\" data-source-line=\"5\" data-source-line-end=\"5\">"))
        XCTAssertFalse(doc.html.contains("data-sourcepos"))
    }

    func testHeadingInsideBlockquoteAndNonLatinTitle() {
        let doc = MarkdownRenderer.render("> ## Quoted\n\n# Übersicht 概要\n\n# !!!\n")
        XCTAssertEqual(doc.headings.map(\.id), ["quoted", "übersicht-概要", "section"])
    }

    // MARK: Math

    func testInlineMathKeepsMarkdownCharactersLiteral() {
        let doc = MarkdownRenderer.render("Energy $a*b*c_i + d_j$ and $x < y$.")
        XCTAssertTrue(doc.hasMath)
        XCTAssertTrue(doc.html.contains("<span class=\"boa-math-source\" data-math=\"inline\">a*b*c_i + d_j</span>"))
        XCTAssertTrue(doc.html.contains("<span class=\"boa-math-source\" data-math=\"inline\">x &lt; y</span>"))
        XCTAssertFalse(doc.html.contains("<em>"))
    }

    func testDisplayMathAcrossLinesAndBracketDelimiters() {
        let doc = MarkdownRenderer.render("$$\n\\frac{a}{b} \\\\ c\n$$\n\nInline \\(p_1\\) and\n\n\\[\nE = mc^2\n\\]\n")
        XCTAssertTrue(doc.html.contains("<div class=\"boa-math-source\" data-math=\"display\" data-source-line=\"1\" data-source-line-end=\"3\">\\frac{a}{b} \\\\ c</div>"))
        XCTAssertTrue(doc.html.contains("<span class=\"boa-math-source\" data-math=\"inline\">p_1</span>"))
        XCTAssertTrue(doc.html.contains("data-math=\"display\" data-source-line=\"7\" data-source-line-end=\"9\">E = mc^2</div>"))
    }

    func testDollarsThatAreNotMathStayText() {
        let doc = MarkdownRenderer.render("Costs $5 and $10, or \\$3 each. Range $5-$10.")
        XCTAssertFalse(doc.hasMath)
        XCTAssertTrue(doc.html.contains("Costs $5 and $10, or $3 each."))
    }

    func testCodeIsNotScannedForMath() {
        let doc = MarkdownRenderer.render("Use `$x$` here.\n\n```sh\necho $HOME:$PATH\n```\n\n~~~\n$$a$$\n~~~\n")
        XCTAssertFalse(doc.hasMath)
        XCTAssertTrue(doc.html.contains("<code>$x$</code>"))
        XCTAssertTrue(doc.html.contains("echo $HOME:$PATH"))
        XCTAssertTrue(doc.html.contains("$$a$$"))
    }

    func testMathInHeadingAppearsInTitle() {
        let doc = MarkdownRenderer.render("## The $\\alpha$ term\n")
        XCTAssertEqual(doc.headings.first?.title, "The \\alpha term")
        XCTAssertTrue(doc.html.contains("<span class=\"boa-math-source\" data-math=\"inline\">\\alpha</span>"))
    }

    // MARK: Alerts and front matter

    func testGitHubAlert() {
        let out = html("> [!WARNING]\n> Careful now.\n\n> [!NOTE]\n\n> Plain quote [!NOTE]\n")
        XCTAssertTrue(out.contains("<div class=\"markdown-alert markdown-alert-warning\">"))
        XCTAssertTrue(out.contains("<p class=\"markdown-alert-title\">Warning</p>"))
        XCTAssertTrue(out.contains("Careful now."))
        XCTAssertFalse(out.contains("[!WARNING]"))
        XCTAssertTrue(out.contains("<div class=\"markdown-alert markdown-alert-note\">"))
        XCTAssertEqual(out.components(separatedBy: "class=\"markdown-alert ").count - 1, 2)
    }

    func testFrontMatterBecomesTableAndKeepsLineNumbers() {
        let doc = MarkdownRenderer.render("---\ntitle: \"A <b>\"\ntags:\n  - x\n  - y\n---\n\n# Body\n")
        XCTAssertEqual(doc.frontMatter?.fields.map(\.key), ["title", "tags"])
        XCTAssertEqual(doc.frontMatter?.fields.first?.value, "A <b>")
        XCTAssertTrue(doc.html.hasPrefix("<div data-source-line=\"1\" data-source-line-end=\"6\">\n<table class=\"yaml-frontmatter\">"))
        XCTAssertTrue(doc.html.contains("<td>A &lt;b&gt;</td>"))
        XCTAssertTrue(doc.html.contains("<td>- x<br />- y</td>"))
        XCTAssertEqual(doc.headings.first?.line, 8)
    }

    func testThematicBreakAtTopIsNotFrontMatter() {
        let doc = MarkdownRenderer.render("---\n\nJust a rule above.\n")
        XCTAssertNil(doc.frontMatter)
        XCTAssertTrue(doc.html.contains("<hr"))
    }

    func testEmptyAndWindowsLineEndings() {
        XCTAssertEqual(html(""), "")
        XCTAssertTrue(html("# A\r\n\r\ntext\r\n").contains("<h1 id=\"a\""))
    }

    // MARK: Repository fixtures

    func testEveryRepositoryFixtureRendersWithoutActiveContent() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        var rendered = 0
        for folder in ["Tests/fixtures", "benchmark/fixtures"] {
            let directory = root.appendingPathComponent(folder)
            guard let files = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) else { continue }
            for case let file as URL in files where ["md", "markdown", "mdown", "mkd", "mdc"].contains(file.pathExtension.lowercased()) {
                let source = try String(contentsOf: file, encoding: .utf8)
                let document = MarkdownRenderer.render(source)
                XCTAssertFalse(document.html.isEmpty, file.lastPathComponent)
                // Escaped text may mention these; only real markup counts.
                let lowered = document.html.lowercased()
                for forbidden in ["<script", "<iframe", "<object", "<embed", "<style", "=\"javascript:", "=\"data:text/html"] {
                    XCTAssertFalse(lowered.contains(forbidden), "\(forbidden) in \(file.lastPathComponent)")
                }
                XCTAssertNil(lowered.range(of: #"<[a-z][^>]*\son[a-z]+\s*="#, options: .regularExpression),
                             "event handler attribute in \(file.lastPathComponent)")
                XCTAssertFalse(document.html.contains("\u{E000}"), file.lastPathComponent)
                rendered += 1
            }
        }
        XCTAssertGreaterThan(rendered, 15)
        print("rendered fixtures: \(rendered)")
    }
}
