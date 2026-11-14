import Foundation
import cmark_gfm
import cmark_gfm_extensions

/// A heading in document order, for the table of contents.
public struct Heading: Equatable {
    public let level: Int
    /// Unique within the document; also the element's `id`.
    public let id: String
    public let title: String
    /// 1-based line of the heading in the original source.
    public let line: Int
}

public struct RenderedDocument {
    /// Body HTML. Raw HTML from the document is never passed through.
    public let html: String
    public let headings: [Heading]
    public let frontMatter: FrontMatter?
    /// True when the HTML contains formulas (`.boa-math-source`) that need typesetting.
    public let hasMath: Bool

    /// Headings in the form the page scripts take.
    public var pageHeadings: [[String: Any]] {
        headings.map { ["level": $0.level, "id": $0.id, "title": $0.title, "line": $0.line] }
    }

    /// The `html` and `headings` entries of the options passed to `window.renderMarkdown`.
    public var pageOptions: [String: Any] {
        ["html": html, "headings": pageHeadings]
    }
}

/// Converts Markdown to HTML with cmark-gfm.
///
/// Enabled: tables, strikethrough, task lists, autolinks, footnotes, GitHub
/// alerts, front matter and TeX math (left as escaped source in `span.math`).
/// Raw HTML is reduced to a fixed set of attribute-free tags (see `HTMLAllowlist`).
/// cmark runs in its default safe mode, so links with unsafe schemes lose their destination.
public enum MarkdownRenderer {
    private static let extensionNames = ["table", "strikethrough", "autolink", "tasklist"]
    private static let options = CMARK_OPT_SOURCEPOS | CMARK_OPT_FOOTNOTES | CMARK_OPT_VALIDATE_UTF8

    public static func render(_ source: String) -> RenderedDocument {
        let normalized = source.replacingOccurrences(of: "\r\n", with: "\n")
        let (frontMatter, body) = FrontMatter.split(normalized)
        let extraction = MathExtractor.extract(body)
        let (text, math, lines) = (extraction.text, extraction.spans, extraction.lines)

        cmark_gfm_core_extensions_ensure_registered()
        guard let parser = cmark_parser_new(options) else {
            return RenderedDocument(html: "", headings: [], frontMatter: frontMatter, hasMath: false)
        }
        defer { cmark_parser_free(parser) }
        for name in extensionNames {
            if let syntaxExtension = cmark_find_syntax_extension(name) {
                cmark_parser_attach_syntax_extension(parser, syntaxExtension)
            }
        }
        text.withCString { cmark_parser_feed(parser, $0, strlen($0)) }
        guard let document = cmark_parser_finish(parser) else {
            return RenderedDocument(html: "", headings: [], frontMatter: frontMatter, hasMath: false)
        }
        defer { cmark_node_free(document) }
        HTMLAllowlist.apply(to: document)
        markAlerts(in: document)

        var html = ""
        if let rendered = cmark_render_html(document, options, cmark_parser_get_syntax_extensions(parser)) {
            html = String(cString: rendered)
            free(rendered)
        }

        let found = headings(in: document, math: math, lines: lines)
        for (heading, position) in found {
            let tag = "<h\(heading.level) data-sourcepos=\"\(position)\">"
            html = html.replacingOccurrences(
                of: tag, with: "<h\(heading.level) id=\"\(escapeHTML(heading.id))\" data-sourcepos=\"\(position)\">")
        }
        html = sourceLines(html, lines: lines)
        html = MathExtractor.restore(html, spans: math)
        if let frontMatter, !frontMatter.html.isEmpty {
            html = "<div data-source-line=\"1\" data-source-line-end=\"\(frontMatter.lineCount)\">\n\(frontMatter.html)</div>\n" + html
        }

        return RenderedDocument(html: html, headings: found.map(\.0), frontMatter: frontMatter, hasMath: !math.isEmpty)
    }

    // MARK: - Headings

    private static func headings(in document: UnsafeMutablePointer<cmark_node>, math: [MathSpan], lines: MathExtractor.LineMap) -> [(Heading, String)] {
        guard let iterator = cmark_iter_new(document) else { return [] }
        defer { cmark_iter_free(iterator) }
        var result: [(Heading, String)] = []
        var used: [String: Int] = [:]
        var current: UnsafeMutablePointer<cmark_node>?
        var title = ""

        while true {
            let event = cmark_iter_next(iterator)
            if event == CMARK_EVENT_DONE { break }
            guard let node = cmark_iter_get_node(iterator) else { continue }
            let type = cmark_node_get_type(node)

            if type == CMARK_NODE_HEADING {
                if event == CMARK_EVENT_ENTER {
                    current = node
                    title = ""
                } else if event == CMARK_EVENT_EXIT, current == node {
                    let plain = MathExtractor.restorePlain(title, spans: math).trimmingCharacters(in: .whitespacesAndNewlines)
                    let id = uniqueID(for: plain, used: &used)
                    let position = "\(cmark_node_get_start_line(node)):\(cmark_node_get_start_column(node))-\(cmark_node_get_end_line(node)):\(cmark_node_get_end_column(node))"
                    let heading = Heading(level: Int(cmark_node_get_heading_level(node)), id: id, title: plain,
                                          line: lines.start(Int(cmark_node_get_start_line(node))))
                    result.append((heading, position))
                    current = nil
                }
            } else if current != nil, event == CMARK_EVENT_ENTER {
                if type == CMARK_NODE_TEXT || type == CMARK_NODE_CODE, let literal = cmark_node_get_literal(node) {
                    title += String(cString: literal)
                } else if type == CMARK_NODE_SOFTBREAK || type == CMARK_NODE_LINEBREAK {
                    title += " "
                }
            }
        }
        return result
    }

    /// GitHub-style anchors: lowercase, punctuation dropped, spaces to hyphens, `-n` for repeats.
    static func slug(_ title: String) -> String {
        var slug = ""
        for scalar in title.lowercased().unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) || scalar == "_" || scalar == "-" {
                slug.unicodeScalars.append(scalar)
            } else if scalar == " " {
                slug += "-"
            }
        }
        return slug
    }

    private static func uniqueID(for title: String, used: inout [String: Int]) -> String {
        let base = slug(title).isEmpty ? "section" : slug(title)
        guard var count = used[base] else {
            used[base] = 0
            return base
        }
        repeat { count += 1 } while used["\(base)-\(count)"] != nil
        used[base] = count
        used["\(base)-\(count)"] = 0
        return "\(base)-\(count)"
    }

    // MARK: - Source lines

    /// cmark's `data-sourcepos="l:c-l:c"` reduced to the line range the page scripts use.
    private static let sourceLinePattern = try! NSRegularExpression(pattern: #" data-sourcepos="(\d+):\d+-(\d+):\d+""#)

    private static func sourceLines(_ html: String, lines: MathExtractor.LineMap) -> String {
        let source = html as NSString
        var result = ""
        var location = 0
        for match in sourceLinePattern.matches(in: html, range: NSRange(location: 0, length: source.length)) {
            result += source.substring(with: NSRange(location: location, length: match.range.location - location))
            let start = Int(source.substring(with: match.range(at: 1))) ?? 1
            let end = Int(source.substring(with: match.range(at: 2))) ?? start
            result += " data-source-line=\"\(lines.start(start))\" data-source-line-end=\"\(max(lines.start(start), lines.end(end)))\""
            location = match.range.location + match.range.length
        }
        result += source.substring(from: location)
        return result
    }

    // MARK: - Alerts

    private static let alertTitles = ["NOTE": "Note", "TIP": "Tip", "IMPORTANT": "Important", "WARNING": "Warning", "CAUTION": "Caution"]

    /// Turns `> [!NOTE]` blockquotes into titled alert boxes.
    private static func markAlerts(in document: UnsafeMutablePointer<cmark_node>) {
        var quotes: [UnsafeMutablePointer<cmark_node>] = []
        if let iterator = cmark_iter_new(document) {
            while true {
                let event = cmark_iter_next(iterator)
                if event == CMARK_EVENT_DONE { break }
                if event == CMARK_EVENT_ENTER, let node = cmark_iter_get_node(iterator),
                   cmark_node_get_type(node) == CMARK_NODE_BLOCK_QUOTE { quotes.append(node) }
            }
            cmark_iter_free(iterator)
        }

        for quote in quotes {
            guard let paragraph = cmark_node_first_child(quote), cmark_node_get_type(paragraph) == CMARK_NODE_PARAGRAPH else { continue }
            // The marker must be alone on the first line; the parser may split it across text nodes.
            var marker = ""
            var markerNodes: [UnsafeMutablePointer<cmark_node>] = []
            var node = cmark_node_first_child(paragraph)
            while let current = node, cmark_node_get_type(current) == CMARK_NODE_TEXT {
                marker += cmark_node_get_literal(current).map { String(cString: $0) } ?? ""
                markerNodes.append(current)
                node = cmark_node_next(current)
            }
            let name = marker.trimmingCharacters(in: .whitespaces)
            guard name.hasPrefix("[!"), name.hasSuffix("]"), let title = alertTitles[String(name.dropFirst(2).dropLast())] else { continue }
            if let lineEnd = node {
                let type = cmark_node_get_type(lineEnd)
                guard type == CMARK_NODE_SOFTBREAK || type == CMARK_NODE_LINEBREAK else { continue }
                markerNodes.append(lineEnd)
            }
            for item in markerNodes { cmark_node_unlink(item); cmark_node_free(item) }
            if cmark_node_first_child(paragraph) == nil { cmark_node_unlink(paragraph); cmark_node_free(paragraph) }

            guard let box = cmark_node_new(CMARK_NODE_CUSTOM_BLOCK) else { continue }
            let kind = name.dropFirst(2).dropLast().lowercased()
            cmark_node_set_on_enter(box, "<div class=\"markdown-alert markdown-alert-\(kind)\">\n<p class=\"markdown-alert-title\">\(title)</p>")
            cmark_node_set_on_exit(box, "</div>")
            while let child = cmark_node_first_child(quote) {
                cmark_node_unlink(child)
                cmark_node_append_child(box, child)
            }
            if cmark_node_replace(quote, box) == 1 { cmark_node_free(quote) } else { cmark_node_free(box) }
        }
    }
}
