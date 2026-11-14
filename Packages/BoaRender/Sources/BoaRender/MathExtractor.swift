import Foundation

/// A formula lifted out of the Markdown source before parsing.
struct MathSpan: Equatable {
    let tex: String
    let display: Bool
}

/// Replaces TeX formulas with opaque tokens so the Markdown parser cannot
/// reinterpret their contents (`*`, `_`, `\\`, `<`), then restores them as
/// escaped text in the rendered HTML.
///
/// Recognized delimiters: `$…$`, `\(…\)` (inline) and `$$…$$`, `\[…\]` (display).
/// Fenced code blocks and inline code spans are left untouched.
enum MathExtractor {
    // Private-use scalars cannot be produced by the tokenizer below from
    // document text: any already present in the source are removed first.
    static let open: Character = "\u{E000}"
    static let close: Character = "\u{E001}"

    struct Extraction {
        let text: String
        let spans: [MathSpan]
        /// Maps lines of `text` back to lines of the source: a formula spanning
        /// several lines collapses to one token, which shifts everything after it.
        let lines: LineMap
    }

    struct LineMap {
        /// `starts[n]` is the source line on which line `n + 1` of the extracted text begins.
        fileprivate let starts: [Int]
        fileprivate let sourceLineCount: Int

        func start(_ line: Int) -> Int {
            starts.indices.contains(line - 1) ? starts[line - 1] : line
        }

        func end(_ line: Int) -> Int {
            starts.indices.contains(line) ? starts[line] - 1 : max(sourceLineCount, start(line))
        }
    }

    static func extract(_ source: String) -> Extraction {
        let chars = Array(source.filter { $0 != open && $0 != close })
        var out: [Character] = []
        out.reserveCapacity(chars.count)
        var spans: [MathSpan] = []
        var i = 0
        var atLineStart = true
        var sourceLine = 1
        var starts = [1]

        func copy(_ range: Range<Int>) {
            for character in chars[range] {
                out.append(character)
                if character == "\n" {
                    sourceLine += 1
                    starts.append(sourceLine)
                }
            }
        }

        func emit(_ range: Range<Int>, delimiters: Range<Int>, display: Bool) {
            out.append(open)
            out.append(contentsOf: String(spans.count))
            out.append(close)
            spans.append(MathSpan(tex: String(chars[range]).trimmingCharacters(in: .whitespacesAndNewlines), display: display))
            sourceLine += chars[delimiters].reduce(0) { $1 == "\n" ? $0 + 1 : $0 }
        }

        while i < chars.count {
            if atLineStart, let end = fencedBlockEnd(chars, from: i) {
                copy(i..<end)
                i = end
                continue
            }
            let c = chars[i]
            atLineStart = c == "\n"

            if c == "`" {
                // Copy a code span verbatim, or the backtick run if it never closes.
                let run = runLength(chars, at: i, of: "`")
                if let end = closingBacktickRun(chars, from: i + run, length: run) {
                    copy(i..<end)
                    atLineStart = false
                    i = end
                } else {
                    copy(i..<(i + run))
                    i += run
                }
                continue
            }

            if c == "\\", i + 1 < chars.count {
                let next = chars[i + 1]
                if next == "(" || next == "[" {
                    let closer: Character = next == "(" ? ")" : "]"
                    if let end = find(chars, from: i + 2, sequence: ["\\", closer], allowBlankLine: next == "[") {
                        emit((i + 2)..<end, delimiters: i..<(end + 2), display: next == "[")
                        i = end + 2
                        continue
                    }
                }
                // Keep the escape intact so `\$` stays a literal dollar sign.
                copy(i..<(i + 2))
                atLineStart = next == "\n"
                i += 2
                continue
            }

            if c == "$" {
                if i + 1 < chars.count, chars[i + 1] == "$" {
                    if let end = find(chars, from: i + 2, sequence: ["$", "$"], allowBlankLine: true), end > i + 2 {
                        emit((i + 2)..<end, delimiters: i..<(end + 2), display: true)
                        i = end + 2
                        continue
                    }
                } else if let end = inlineDollarEnd(chars, from: i + 1) {
                    emit((i + 1)..<end, delimiters: i..<(end + 1), display: false)
                    i = end + 1
                    continue
                }
            }

            copy(i..<(i + 1))
            i += 1
        }
        return Extraction(text: String(out), spans: spans, lines: LineMap(starts: starts, sourceLineCount: sourceLine))
    }

    /// Replaces tokens in rendered HTML with elements that carry the escaped TeX source.
    /// A paragraph holding nothing but one display formula becomes a block element.
    static func restore(_ html: String, spans: [MathSpan]) -> String {
        guard !spans.isEmpty else { return html }
        var result = ""
        result.reserveCapacity(html.count)
        var index = html.startIndex
        while let start = html[index...].firstIndex(of: open) {
            guard let end = html[start...].firstIndex(of: close),
                  let number = Int(html[html.index(after: start)..<end]), spans.indices.contains(number) else {
                result += html[index..<start]
                index = html.index(after: start)
                continue
            }
            let span = spans[number]
            let before = html[index..<start]
            let after = html[html.index(after: end)...]
            if span.display, after.hasPrefix("</p>"), let paragraph = before.range(of: "<p", options: .backwards),
               before[paragraph.upperBound...].last == ">", !before[paragraph.upperBound...].dropLast().contains(">") {
                // `<p attrs>TOKEN</p>` → `<div class=… attrs>tex</div>`
                let attributes = before[paragraph.upperBound...].dropLast()
                result += before[..<paragraph.lowerBound]
                result += "<div class=\"boa-math-source\" data-math=\"display\"\(attributes)>\(escapeHTML(span.tex))</div>"
                index = html.index(end, offsetBy: 5)
                continue
            }
            result += before
            result += "<span class=\"boa-math-source\" data-math=\"\(span.display ? "display" : "inline")\">\(escapeHTML(span.tex))</span>"
            index = html.index(after: end)
        }
        result += html[index...]
        return result
    }

    /// Replaces tokens in plain text (heading titles) with the TeX source.
    static func restorePlain(_ text: String, spans: [MathSpan]) -> String {
        guard text.contains(open) else { return text }
        var result = ""
        var index = text.startIndex
        while let start = text[index...].firstIndex(of: open) {
            result += text[index..<start]
            guard let end = text[start...].firstIndex(of: close),
                  let number = Int(text[text.index(after: start)..<end]), spans.indices.contains(number) else {
                index = text.index(after: start)
                continue
            }
            result += spans[number].tex
            index = text.index(after: end)
        }
        result += text[index...]
        return result
    }

    // MARK: - Scanning helpers

    private static func runLength(_ chars: [Character], at index: Int, of character: Character) -> Int {
        var n = 0
        while index + n < chars.count, chars[index + n] == character { n += 1 }
        return n
    }

    private static func closingBacktickRun(_ chars: [Character], from start: Int, length: Int) -> Int? {
        var i = start
        while i < chars.count {
            if chars[i] == "`" {
                let run = runLength(chars, at: i, of: "`")
                if run == length { return i + run }
                i += run
            } else {
                i += 1
            }
        }
        return nil
    }

    /// If a fenced code block opens at `start` (a line start), returns the index just past it.
    private static func fencedBlockEnd(_ chars: [Character], from start: Int) -> Int? {
        var i = start
        var indent = 0
        while i < chars.count, chars[i] == " ", indent < 3 { i += 1; indent += 1 }
        guard i < chars.count, chars[i] == "`" || chars[i] == "~" else { return nil }
        let fence = chars[i]
        let length = runLength(chars, at: i, of: fence)
        guard length >= 3 else { return nil }
        // Move to the line after the opening fence.
        var line = i
        while line < chars.count, chars[line] != "\n" { line += 1 }
        line += 1
        while line < chars.count {
            var j = line
            var spaces = 0
            while j < chars.count, chars[j] == " ", spaces < 3 { j += 1; spaces += 1 }
            let run = j < chars.count && chars[j] == fence ? runLength(chars, at: j, of: fence) : 0
            var lineEnd = j + run
            var onlySpace = true
            while lineEnd < chars.count, chars[lineEnd] != "\n" {
                if chars[lineEnd] != " " && chars[lineEnd] != "\t" && chars[lineEnd] != "\r" { onlySpace = false }
                lineEnd += 1
            }
            let next = min(lineEnd + 1, chars.count)
            if run >= length && onlySpace { return next }
            line = next
        }
        return chars.count // An unclosed fence runs to the end of the document.
    }

    private static func find(_ chars: [Character], from start: Int, sequence: [Character], allowBlankLine: Bool) -> Int? {
        var i = start
        while i + sequence.count <= chars.count {
            if Array(chars[i..<(i + sequence.count)]) == sequence { return i }
            if !allowBlankLine, chars[i] == "\n", i + 1 < chars.count, chars[i + 1] == "\n" { return nil }
            if chars[i] == "\\", sequence.first != "\\" { i += 2 } else { i += 1 }
        }
        return nil
    }

    /// Pandoc's rule: the opening `$` is followed by a non-space, the closing `$`
    /// is preceded by a non-space and not followed by a digit.
    private static func inlineDollarEnd(_ chars: [Character], from start: Int) -> Int? {
        guard start < chars.count, !chars[start].isWhitespace, chars[start] != "$" else { return nil }
        var i = start
        while i < chars.count {
            let c = chars[i]
            if c == "\\" { i += 2; continue }
            if c == "\n", i + 1 < chars.count, chars[i + 1] == "\n" { return nil }
            if c == "`" { return nil }
            if c == "$" {
                let before = chars[i - 1]
                let after: Character? = i + 1 < chars.count ? chars[i + 1] : nil
                if i > start, !before.isWhitespace, !(after?.isNumber ?? false) { return i }
                return nil
            }
            i += 1
        }
        return nil
    }
}

func escapeHTML(_ text: String) -> String {
    var result = ""
    result.reserveCapacity(text.count)
    for character in text {
        switch character {
        case "&": result += "&amp;"
        case "<": result += "&lt;"
        case ">": result += "&gt;"
        case "\"": result += "&quot;"
        default: result.append(character)
        }
    }
    return result
}
