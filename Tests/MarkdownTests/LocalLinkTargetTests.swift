import XCTest

/// Editor-style `path:line[:column]` link targets (issue #71).
final class LocalLinkTargetTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("local-link-target-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let directory { try? FileManager.default.removeItem(at: directory) }
    }

    private var documentURL: URL { directory.appendingPathComponent("doc.md") }

    @discardableResult
    private func makeFile(_ name: String) throws -> URL {
        let url = directory.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "content\n".write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Plain local links keep working

    func testResolvesExistingFileWithoutSuffix() throws {
        let file = try makeFile("Foo.java")

        let target = try XCTUnwrap(LinkNavigation.resolveLocalLink(href: "Foo.java", relativeTo: documentURL))

        XCTAssertEqual(target.url.path, file.path)
        XCTAssertNil(target.line)
        XCTAssertNil(target.fragment)
    }

    func testKeepsAnchorFragmentForMarkdownTarget() throws {
        try makeFile("notes.md")

        let target = try XCTUnwrap(LinkNavigation.resolveLocalLink(href: "notes.md#section", relativeTo: documentURL))

        XCTAssertEqual(target.url.lastPathComponent, "notes.md")
        XCTAssertEqual(target.fragment, "section")
        XCTAssertNil(target.line)
    }

    // MARK: - Line suffix support

    func testStripsEditorLineSuffixWhenBaseFileExists() throws {
        let file = try makeFile("Foo.java")

        let target = try XCTUnwrap(LinkNavigation.resolveLocalLink(href: "Foo.java:57", relativeTo: documentURL))

        XCTAssertEqual(target.url.path, file.path, "The `:57` suffix must not become part of the file name")
        XCTAssertEqual(target.line, 57)
    }

    func testStripsLineAndColumnSuffix() throws {
        let file = try makeFile("Foo.java")

        let target = try XCTUnwrap(LinkNavigation.resolveLocalLink(href: "Foo.java:57:12", relativeTo: documentURL))

        XCTAssertEqual(target.url.path, file.path)
        XCTAssertEqual(target.line, 57, "The first number is the line; the second is the column")
    }

    func testStripsSuffixForPercentEncodedRelativeHref() throws {
        let file = try makeFile("设计/文件.java")
        let href = "设计/文件.java"
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)! + ":57"

        let target = try XCTUnwrap(LinkNavigation.resolveLocalLink(href: href, relativeTo: documentURL))

        XCTAssertEqual(target.url.path, file.path)
        XCTAssertEqual(target.line, 57)
    }

    func testStripsSuffixForMarkdownTargetAndKeepsFragment() throws {
        try makeFile("notes.md")

        let target = try XCTUnwrap(LinkNavigation.resolveLocalLink(href: "./notes.md:12#section", relativeTo: documentURL))

        XCTAssertEqual(target.url.lastPathComponent, "notes.md")
        XCTAssertEqual(target.line, 12)
        XCTAssertEqual(target.fragment, "section")
    }

    // MARK: - Precision: only strip when the literal target is missing and the base exists

    func testPrefersLiteralFileThatReallyContainsTheSuffix() throws {
        let literal = try makeFile("Foo.java:57")

        let target = try XCTUnwrap(LinkNavigation.resolveLocalLink(href: "Foo.java:57", relativeTo: documentURL))

        XCTAssertEqual(target.url.path, literal.path)
        XCTAssertNil(target.line)
    }

    func testKeepsRawTargetWhenNeitherLiteralNorBaseFileExists() {
        let target = LinkNavigation.resolveLocalLink(href: "Missing.java:57", relativeTo: documentURL)

        XCTAssertEqual(target?.url.lastPathComponent, "Missing.java:57",
                       "An unresolved target must stay untouched so the failure can be reported")
        XCTAssertNil(target?.line)
    }

    func testKeepsRawTargetForNonNumericSuffix() throws {
        try makeFile("Foo.java")

        let target = try XCTUnwrap(LinkNavigation.resolveLocalLink(href: "Foo.java:beta", relativeTo: documentURL))

        XCTAssertEqual(target.url.lastPathComponent, "Foo.java:beta")
        XCTAssertNil(target.line)
    }

    func testKeepsRawTargetForZeroLine() throws {
        try makeFile("Foo.java")

        let target = try XCTUnwrap(LinkNavigation.resolveLocalLink(href: "Foo.java:0", relativeTo: documentURL))

        XCTAssertEqual(target.url.lastPathComponent, "Foo.java:0")
        XCTAssertNil(target.line)
    }

    func testKeepsRawTargetForNonNumericColumn() throws {
        try makeFile("Foo.java")

        let target = try XCTUnwrap(LinkNavigation.resolveLocalLink(href: "Foo.java:57:beta", relativeTo: documentURL))

        XCTAssertEqual(target.url.lastPathComponent, "Foo.java:57:beta")
        XCTAssertNil(target.line)
    }

    func testKeepsRawTargetForOverlongNumber() throws {
        try makeFile("Foo.java")

        let target = try XCTUnwrap(LinkNavigation.resolveLocalLink(href: "Foo.java:12345678", relativeTo: documentURL))

        XCTAssertNil(target.line, "Absurd line numbers must not be treated as source references")
    }

    func testDirectoryOnlyTargetIsNotStripped() throws {
        try makeFile("folder/notes.md")

        let target = try XCTUnwrap(LinkNavigation.resolveLocalLink(href: "folder:12", relativeTo: documentURL))

        XCTAssertNil(target.line, "A bare directory name must not be split into a file reference")
    }

    // MARK: - What clicking decides

    func testMarkdownLineSuffixNavigatesToSourceLineInsideBoaMarkdown() throws {
        try makeFile("notes.md")

        let target = try XCTUnwrap(LinkNavigation.resolveLocalLink(href: "notes.md:12", relativeTo: documentURL))

        XCTAssertEqual(LinkNavigation.action(for: target), .openBoaMarkdown(.line(12)))
    }

    func testMarkdownAnchorStillNavigatesToTheHeading() throws {
        try makeFile("notes.md")

        let target = try XCTUnwrap(LinkNavigation.resolveLocalLink(href: "notes.md#section", relativeTo: documentURL))

        XCTAssertEqual(LinkNavigation.action(for: target), .openBoaMarkdown(.anchor("section")))
    }

    func testMarkdownTargetWithoutPositionOpensTheDocument() throws {
        try makeFile("notes.md")

        let target = try XCTUnwrap(LinkNavigation.resolveLocalLink(href: "notes.md", relativeTo: documentURL))

        XCTAssertEqual(LinkNavigation.action(for: target), .openBoaMarkdown(nil))
    }

    func testSourceFileLineSuffixAsksBeforeOpeningTheFile() throws {
        try makeFile("Foo.java")

        let target = try XCTUnwrap(LinkNavigation.resolveLocalLink(href: "Foo.java:57", relativeTo: documentURL))

        XCTAssertEqual(LinkNavigation.action(for: target), .confirmThenOpen)
    }

    func testTSVTargetIsHandledAsADocument() throws {
        try makeFile("data.tsv")

        let target = try XCTUnwrap(LinkNavigation.resolveLocalLink(href: "data.tsv:3", relativeTo: documentURL))

        XCTAssertEqual(LinkNavigation.action(for: target), .openBoaMarkdown(.line(3)))
    }

    // MARK: - Links stay inside the document's folder tree

    func testFilesInNestedFoldersAreAllowed() throws {
        let file = try makeFile("a/b/c/deep.txt")

        let target = try XCTUnwrap(LinkNavigation.resolveLocalLink(href: "a/b/c/deep.txt", relativeTo: documentURL))

        XCTAssertEqual(target.url.path, file.path)
    }

    func testTraversalAndAbsoluteLinksResolveToNothing() throws {
        let outside = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("outside-\(UUID().uuidString).txt")
        try "secret\n".write(to: outside, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: outside) }
        try makeFile("inside/readme.md")

        let hrefs = [
            "../\(outside.lastPathComponent)",
            "inside/../../\(outside.lastPathComponent)",
            outside.path,
            "file://" + outside.path,
            "/etc/hosts",
        ]
        for href in hrefs {
            XCTAssertNil(LinkNavigation.resolveLocalLink(href: href, relativeTo: documentURL),
                         "\(href) must not resolve to a target")
        }
    }

    func testSymlinkPointingOutsideTheTreeIsRefused() throws {
        let outsideDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("outside-dir-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: outsideDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outsideDirectory) }
        let outsideFile = outsideDirectory.appendingPathComponent("target.txt")
        try "secret\n".write(to: outsideFile, atomically: true, encoding: .utf8)

        try FileManager.default.createSymbolicLink(at: directory.appendingPathComponent("link.txt"), withDestinationURL: outsideFile)
        try FileManager.default.createSymbolicLink(at: directory.appendingPathComponent("linkdir"), withDestinationURL: outsideDirectory)

        XCTAssertNil(LinkNavigation.resolveLocalLink(href: "link.txt", relativeTo: documentURL),
                     "A symlink that leaves the folder tree must not be followed")
        XCTAssertNil(LinkNavigation.resolveLocalLink(href: "linkdir/target.txt", relativeTo: documentURL),
                     "A file reached through a symlinked folder that leaves the tree must not be followed")
    }

    func testSymlinkStayingInsideTheTreeIsAllowed() throws {
        let real = try makeFile("real/data.txt")
        try FileManager.default.createSymbolicLink(at: directory.appendingPathComponent("alias.txt"), withDestinationURL: real)

        let target = try XCTUnwrap(LinkNavigation.resolveLocalLink(href: "alias.txt", relativeTo: documentURL))

        XCTAssertEqual(target.url.lastPathComponent, "alias.txt")
    }

    func testMissingFileInsideTheTreeIsStillReportedAsATarget() {
        let target = LinkNavigation.resolveLocalLink(href: "missing/file.txt", relativeTo: documentURL)

        XCTAssertEqual(target?.url.lastPathComponent, "file.txt", "A missing file stays a target so the failure notice can name it")
    }

    // MARK: - What may be opened from a link

    func testOrdinaryFileAsksBeforeOpening() throws {
        for name in ["photo.png", "report.pdf", "notes.txt", "Foo.java", "data.csv"] {
            try makeFile(name)
            let target = try XCTUnwrap(LinkNavigation.resolveLocalLink(href: name, relativeTo: documentURL))
            XCTAssertEqual(LinkNavigation.action(for: target), .confirmThenOpen, "\(name) should ask first")
        }
    }

    func testDocumentsOpenInsideBoaMarkdownWithoutAsking() throws {
        try makeFile("other.md")

        let target = try XCTUnwrap(LinkNavigation.resolveLocalLink(href: "other.md", relativeTo: documentURL))

        XCTAssertEqual(LinkNavigation.action(for: target), .openBoaMarkdown(nil))
    }

    func testCodeCarryingFilesAreOnlyRevealed() throws {
        for name in ["run.command", "setup.sh", "Tool.app/Contents/Info.plist", "installer.pkg", "disk.dmg",
                     "tool.jar", "script.py", "macro.scpt", "link.webloc", "UPPER.SH"] {
            try makeFile(name)
        }
        for name in ["run.command", "setup.sh", "installer.pkg", "disk.dmg", "tool.jar", "script.py", "macro.scpt",
                     "link.webloc", "UPPER.SH"] {
            let target = try XCTUnwrap(LinkNavigation.resolveLocalLink(href: name, relativeTo: documentURL))
            XCTAssertEqual(LinkNavigation.action(for: target), .revealInFinder, "\(name) must never be opened from a link")
        }
    }

    func testApplicationBundleAndFolderAreOnlyRevealed() throws {
        try makeFile("Tool.app/Contents/Info.plist")
        try makeFile("plainfolder/readme.txt")

        let app = try XCTUnwrap(LinkNavigation.resolveLocalLink(href: "Tool.app", relativeTo: documentURL))
        let folder = try XCTUnwrap(LinkNavigation.resolveLocalLink(href: "plainfolder", relativeTo: documentURL))

        XCTAssertEqual(LinkNavigation.action(for: app), .revealInFinder)
        XCTAssertEqual(LinkNavigation.action(for: folder), .revealInFinder)
    }

    func testFileWithTheExecutableBitIsOnlyRevealedWhateverItsName() throws {
        let file = try makeFile("mystery")
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
        let plain = try makeFile("mystery.txt")
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: plain.path)

        let named = try XCTUnwrap(LinkNavigation.resolveLocalLink(href: "mystery", relativeTo: documentURL))
        let txt = try XCTUnwrap(LinkNavigation.resolveLocalLink(href: "mystery.txt", relativeTo: documentURL))

        XCTAssertEqual(LinkNavigation.action(for: named), .revealInFinder)
        XCTAssertEqual(LinkNavigation.action(for: txt), .revealInFinder)
    }

    // MARK: - Clipboard text for failed destinations

    func testClipboardTextUsesPlainPathForLocalFiles() {
        let url = URL(fileURLWithPath: "/Users/me/docs/设计 文档.java")

        XCTAssertEqual(LinkNavigation.clipboardText(for: url), "/Users/me/docs/设计 文档.java")
    }

    func testClipboardTextUsesFullURLForRemoteDestinations() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/a?b=c"))

        XCTAssertEqual(LinkNavigation.clipboardText(for: url), "https://example.com/a?b=c")
    }
}
