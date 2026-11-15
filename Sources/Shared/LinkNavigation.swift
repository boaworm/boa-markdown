import Foundation
import UniformTypeIdentifiers

/// A clicked local link resolved against the current document.
struct LocalLinkTarget: Equatable {
    let url: URL
    /// Percent-decoded `#fragment` from the original href, when present.
    let fragment: String?
    /// 1-based source line taken from an editor-style `path:line[:column]` suffix.
    let line: Int?
}

/// What clicking a resolved local link asks BoaMarkdown to do.
enum LocalLinkAction: Equatable {
    /// Open the file in BoaMarkdown itself, optionally at a source line or anchor.
    case openBoaMarkdown(DocumentPosition?)
    /// An ordinary file in the document's folder tree: ask the user, then hand it to its macOS application.
    case confirmThenOpen
    /// A folder, or anything that can run code (application, bundle, script, executable):
    /// show it in Finder and never open it.
    case revealInFinder
}

enum LinkNavigation {

    /// Document types that BoaMarkdown both hosts and can position inside.
    static let documentExtensions: Set<String> = ["md", "mdx", "markdown", "mdown", "mkd", "mkdn", "mkdown", "mdwn", "rmd", "qmd", "mdoc", "mdc", "mmd", "livemd", "tsv"]

    /// Resolves a clicked local href, accepting the `path:line[:column]` form that
    /// editors and chat tools emit (e.g. `/src/Foo.java:57`). The suffix is only
    /// stripped when the literal target is missing and the stripped file exists, so
    /// a real file whose name contains a colon keeps winning.
    ///
    /// Only targets inside the document's own folder tree are followed (see `resolveLocalURL`
    /// and `isInsideDocumentTree`); anything else resolves to `nil`.
    static func resolveLocalLink(href: String, relativeTo fileURL: URL) -> LocalLinkTarget? {
        let parts = splitHref(href)
        guard let target = resolveLocalURL(href: parts.path, relativeTo: fileURL),
              isInsideDocumentTree(target, of: fileURL) else { return nil }
        if FileManager.default.fileExists(atPath: target.path) {
            return LocalLinkTarget(url: target, fragment: parts.fragment, line: nil)
        }
        guard let reference = lineReference(in: target),
              isInsideDocumentTree(reference.url, of: fileURL),
              isRegularFile(reference.url) else {
            return LocalLinkTarget(url: target, fragment: parts.fragment, line: nil)
        }
        return LocalLinkTarget(url: reference.url, fragment: parts.fragment, line: reference.line)
    }

    /// Resolves a clicked href to a path below the document's folder, purely by its text.
    /// Absolute paths, `file:` URLs and any `..` component are refused, so a link can only
    /// name something at or under the folder that holds the document.
    static func resolveLocalURL(href: String, relativeTo fileURL: URL) -> URL? {
        let decoded = href.removingPercentEncoding ?? href

        if decoded.isEmpty { return nil }

        if decoded.hasPrefix("#") { return nil }

        guard !decoded.contains("\0"),
              !decoded.hasPrefix("/"),
              !decoded.lowercased().hasPrefix("file:") else { return nil }

        let components = decoded.split(separator: "/").map(String.init)
        guard !components.contains("..") else { return nil }

        var targetURL = fileURL.deletingLastPathComponent()
        for component in components where component != "." {
            targetURL.appendPathComponent(component)
        }
        return targetURL
    }

    /// True when `url`, after following symbolic links, is the document's folder or inside it.
    /// This closes the one way out that the text checks cannot see: a link that names a symlink
    /// pointing elsewhere.
    static func isInsideDocumentTree(_ url: URL, of fileURL: URL) -> Bool {
        let root = fileURL.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL.path
        let path = url.resolvingSymlinksInPath().standardizedFileURL.path
        if path == root { return true }
        return path.hasPrefix(root.hasSuffix("/") ? root : root + "/")
    }

    /// Text to place on the pasteboard for a destination that could not be opened:
    /// a plain filesystem path for local files, the full URL otherwise.
    static func clipboardText(for url: URL) -> String {
        url.isFileURL ? url.path : url.absoluteString
    }

    /// Chooses between in-app document navigation (line or anchor), asking before handing an
    /// ordinary file to macOS, and only revealing things that could run code. Editor-style line
    /// suffixes only apply to documents, so a source file such as `Foo.java:57` is offered to
    /// its application instead of failing.
    static func action(for link: LocalLinkTarget) -> LocalLinkAction {
        guard documentExtensions.contains(link.url.pathExtension.lowercased()) else {
            return mightRunCodeOrIsFolder(link.url) ? .revealInFinder : .confirmThenOpen
        }
        if let line = link.line { return .openBoaMarkdown(.line(line)) }
        if let fragment = link.fragment, !fragment.isEmpty { return .openBoaMarkdown(.anchor(fragment)) }
        return .openBoaMarkdown(nil)
    }

    // MARK: - Things that must never be launched from a link

    /// Extensions that launch, install or mount something when opened, even though a
    /// default application normally handles them. Matched case-insensitively.
    private static let launchableExtensions: Set<String> = [
        "app", "command", "tool", "workflow", "action", "scpt", "scptd", "applescript", "terminal", "term",
        "sh", "bash", "zsh", "csh", "ksh", "fish", "py", "pl", "rb", "php", "ps1",
        "pkg", "mpkg", "dmg", "jar", "exe", "bat", "cmd", "com", "msi", "vbs",
        "webloc", "fileloc", "inetloc", "url", "shortcut",
        "prefpane", "saver", "bundle", "framework", "plugin", "kext", "service", "xpc", "appex",
    ]

    /// True for folders, application and other bundles, scripts, and executables.
    /// Missing files are not treated as risky here; the caller reports them separately.
    static func mightRunCodeOrIsFolder(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        if launchableExtensions.contains(ext) { return true }

        if !ext.isEmpty, let type = UTType(filenameExtension: ext),
           type.conforms(to: .executable) || type.conforms(to: .application) || type.conforms(to: .script)
            || type.conforms(to: .bundle) || type.conforms(to: .package) {
            return true
        }

        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey, .isExecutableKey]) else { return false }
        if values.isDirectory == true || values.isPackage == true { return true }
        return values.isExecutable == true
    }

    // MARK: - Editor-style suffixes

    /// Splits `name:line[:column]` into the real file name and its 1-based line.
    private static func splitLineSuffix(_ component: String) -> (name: String, line: Int)? {
        let fields = component.split(separator: ":", omittingEmptySubsequences: false)
        guard fields.count == 2 || fields.count == 3 else { return nil }
        let name = String(fields[0])
        guard !name.isEmpty, name != ".", name != ".." else { return nil }
        guard let line = numericField(fields[1]) else { return nil }
        if fields.count == 3, numericField(fields[2]) == nil { return nil }
        return (name, line)
    }

    private static func lineReference(in url: URL) -> (url: URL, line: Int)? {
        guard let split = splitLineSuffix(url.lastPathComponent) else { return nil }
        return (url.deletingLastPathComponent().appendingPathComponent(split.name), split.line)
    }

    private static func numericField(_ field: Substring) -> Int? {
        guard !field.isEmpty, field.count <= 9,
              field.allSatisfy({ $0.isASCII && $0.isNumber }),
              let value = Int(field), value > 0, value <= 9_999_999 else { return nil }
        return value
    }

    private static func isRegularFile(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return false }
        return !isDirectory.boolValue
    }

    private static func splitHref(_ href: String) -> (path: String, fragment: String?) {
        guard let hashRange = href.range(of: "#") else { return (href, nil) }
        return (String(href[href.startIndex..<hashRange.lowerBound]), String(href[hashRange.upperBound...]))
    }
}
