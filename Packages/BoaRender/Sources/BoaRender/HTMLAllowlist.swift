import Foundation
import cmark_gfm

/// Decides what happens to raw HTML written in a document.
///
/// A short list of tags is re-emitted in a fixed, attribute-free form. Every
/// other tag is dropped. Text between dropped tags is kept, except inside
/// elements whose content is not prose (`script`, `style`, …).
enum HTMLAllowlist {
    static let allowed: Set<String> = ["br", "sub", "sup", "kbd", "mark", "u", "details", "summary"]
    private static let void: Set<String> = ["br"]
    private static let swallowed: Set<String> = ["script", "style", "head", "title", "iframe", "object", "embed", "svg", "math", "template", "textarea", "noscript"]
    private static let structural: Set<String> = ["details", "summary"]

    struct Tag: Equatable {
        let name: String
        let closing: Bool
    }

    /// Parses a single tag such as `<kbd>`, `</sub >` or `<img src="x">`. Comments and other constructs return nil.
    static func tag(_ text: String) -> Tag? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("<"), trimmed.hasSuffix(">"), !trimmed.hasPrefix("<!"), !trimmed.hasPrefix("<?") else { return nil }
        var body = trimmed.dropFirst().dropLast()
        let closing = body.hasPrefix("/")
        if closing { body = body.dropFirst() }
        let name = body.prefix { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }
        guard let first = name.first, first.isLetter else { return nil }
        return Tag(name: name.lowercased(), closing: closing)
    }

    /// The fixed markup for an allowed tag. Attributes in the source are never copied.
    static func markup(for tag: Tag) -> String? {
        guard allowed.contains(tag.name) else { return nil }
        if void.contains(tag.name) { return tag.closing ? nil : "<\(tag.name) />" }
        return tag.closing ? "</\(tag.name)>" : "<\(tag.name)>"
    }

    /// Rewrites every raw HTML node in `document` in place.
    static func apply(to document: UnsafeMutablePointer<cmark_node>) {
        var nodes: [UnsafeMutablePointer<cmark_node>] = []
        if let iterator = cmark_iter_new(document) {
            while cmark_iter_next(iterator) != CMARK_EVENT_DONE {
                guard let node = cmark_iter_get_node(iterator) else { continue }
                let type = cmark_node_get_type(node)
                if type == CMARK_NODE_HTML_INLINE || type == CMARK_NODE_HTML_BLOCK { nodes.append(node) }
            }
            cmark_iter_free(iterator)
        }

        var freed = Set<UnsafeMutablePointer<cmark_node>>()
        for node in nodes where !freed.contains(node) {
            let literal = cmark_node_get_literal(node).map { String(cString: $0) } ?? ""
            if cmark_node_get_type(node) == CMARK_NODE_HTML_BLOCK {
                replace(node, with: CMARK_NODE_CUSTOM_BLOCK, markup: blockMarkup(literal))
                freed.insert(node)
                continue
            }
            let parsed = tag(literal)
            if let parsed, !parsed.closing, swallowed.contains(parsed.name) {
                // Drop everything up to and including the matching closing tag.
                var next = cmark_node_next(node)
                while let sibling = next {
                    next = cmark_node_next(sibling)
                    let isEnd = cmark_node_get_type(sibling) == CMARK_NODE_HTML_INLINE
                        && cmark_node_get_literal(sibling).flatMap({ tag(String(cString: $0)) }) == Tag(name: parsed.name, closing: true)
                    cmark_node_unlink(sibling)
                    cmark_node_free(sibling)
                    freed.insert(sibling)
                    if isEnd { break }
                }
            }
            replace(node, with: CMARK_NODE_CUSTOM_INLINE, markup: parsed.flatMap(markup(for:)))
            freed.insert(node)
        }
    }

    private static func replace(_ node: UnsafeMutablePointer<cmark_node>, with type: cmark_node_type, markup: String?) {
        if let markup, !markup.isEmpty, let replacement = cmark_node_new(type) {
            cmark_node_set_on_enter(replacement, markup)
            if cmark_node_replace(node, replacement) == 0 {
                cmark_node_free(replacement)
                cmark_node_unlink(node)
            }
        } else {
            cmark_node_unlink(node)
        }
        cmark_node_free(node)
    }

    /// Allowed tags and escaped text from an HTML block; nil when nothing visible remains.
    static func blockMarkup(_ literal: String) -> String? {
        var output = ""
        var hasStructure = false
        var skipUntil: String?
        var rest = Substring(literal)

        while !rest.isEmpty {
            guard let open = rest.firstIndex(of: "<") else {
                if skipUntil == nil { output += escapeHTML(String(rest)) }
                break
            }
            if skipUntil == nil { output += escapeHTML(String(rest[..<open])) }
            let tail = rest[open...]
            let end: Substring.Index?
            if tail.hasPrefix("<!--") {
                end = tail.range(of: "-->")?.upperBound
            } else {
                end = tail.firstIndex(of: ">").map { tail.index(after: $0) }
            }
            guard let end else {
                // A stray `<` with no closing `>`: plain text.
                if skipUntil == nil { output += escapeHTML(String(tail)) }
                break
            }
            if let parsed = tag(String(tail[..<end])) {
                if let waiting = skipUntil {
                    if parsed.closing && parsed.name == waiting { skipUntil = nil }
                } else if !parsed.closing && swallowed.contains(parsed.name) {
                    skipUntil = parsed.name
                } else if let markup = markup(for: parsed) {
                    output += markup
                    if structural.contains(parsed.name) { hasStructure = true }
                }
            }
            rest = tail[end...]
        }

        let visible = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if visible.isEmpty { return nil }
        return hasStructure ? visible : "<p>\(visible)</p>"
    }
}
