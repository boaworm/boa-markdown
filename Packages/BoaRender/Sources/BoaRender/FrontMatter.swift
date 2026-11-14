import Foundation

/// A leading `---` … `---` metadata block.
public struct FrontMatter: Equatable {
    /// The text between the delimiters, unparsed.
    public let raw: String
    /// Top-level `key: value` pairs in document order. Nested lines are folded into the preceding value.
    public let fields: [(key: String, value: String)]

    public static func == (lhs: FrontMatter, rhs: FrontMatter) -> Bool {
        lhs.raw == rhs.raw
    }

    /// Splits `source` into front matter and body. The body keeps its original
    /// line numbers: the metadata lines are replaced by empty ones.
    static func split(_ source: String) -> (frontMatter: FrontMatter?, body: String) {
        var lines = source.components(separatedBy: "\n")
        guard let first = lines.first, isDelimiter(first, closing: false) else { return (nil, source) }
        guard let end = lines.dropFirst().firstIndex(where: { isDelimiter($0, closing: true) }) else { return (nil, source) }
        let raw = lines[1..<end].joined(separator: "\n")
        for index in 0...end { lines[index] = "" }
        return (FrontMatter(raw: raw, fields: parse(raw)), lines.joined(separator: "\n"))
    }

    private static func isDelimiter(_ line: String, closing: Bool) -> Bool {
        let trimmed = line.trimmingCharacters(in: CharacterSet(charactersIn: " \t\r"))
        return trimmed == "---" || (closing && trimmed == "...")
    }

    private static func parse(_ raw: String) -> [(key: String, value: String)] {
        var fields: [(key: String, value: String)] = []
        for line in raw.components(separatedBy: "\n") {
            let text = line.trimmingCharacters(in: CharacterSet(charactersIn: "\r"))
            if text.trimmingCharacters(in: .whitespaces).isEmpty || text.hasPrefix("#") { continue }
            if let colon = text.firstIndex(of: ":"), let start = text.first, !start.isWhitespace, start != "-" {
                let key = String(text[..<colon]).trimmingCharacters(in: .whitespaces)
                let value = String(text[text.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                fields.append((key, unquote(value)))
            } else if !fields.isEmpty {
                let extra = text.trimmingCharacters(in: .whitespaces)
                let last = fields.count - 1
                fields[last].value = fields[last].value.isEmpty ? extra : fields[last].value + "\n" + extra
            }
        }
        return fields
    }

    private static func unquote(_ value: String) -> String {
        guard value.count >= 2, let first = value.first, first == value.last, first == "\"" || first == "'" else { return value }
        return String(value.dropFirst().dropLast())
    }

    /// The metadata as an HTML table, or a preformatted block when no fields could be read.
    var html: String {
        guard !fields.isEmpty else {
            return raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "" : "<pre><code class=\"language-yaml\">\(escapeHTML(raw))</code></pre>\n"
        }
        let rows = fields.map { field in
            "<tr><th>\(escapeHTML(field.key))</th><td>\(escapeHTML(field.value).replacingOccurrences(of: "\n", with: "<br />"))</td></tr>"
        }
        return "<table class=\"yaml-frontmatter\">\n<tbody>\n\(rows.joined(separator: "\n"))\n</tbody>\n</table>\n"
    }

    /// Number of source lines the block occupies, delimiters included.
    var lineCount: Int { raw.components(separatedBy: "\n").count + 2 }
}
