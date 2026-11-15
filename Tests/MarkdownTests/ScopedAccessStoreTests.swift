import XCTest

final class ScopedAccessStoreTests: XCTestCase {
    private var directory: URL!
    private var suite: String!
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("scoped-access-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        suite = "ScopedAccessStoreTests-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    }

    override func tearDownWithError() throws {
        if let directory { try? FileManager.default.removeItem(at: directory) }
        defaults?.removePersistentDomain(forName: suite)
    }

    private func makeStore(limit: Int = 200) -> ScopedAccessStore {
        ScopedAccessStore(defaults: defaults, key: "bookmarks", limit: limit)
    }

    private func makeFolder(_ name: String) throws -> URL {
        let url = directory.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func testNothingIsRememberedAtFirst() {
        let store = makeStore()

        XCTAssertEqual(store.rememberedPaths, [])
        XCTAssertFalse(store.startAccess(coveringPath: directory.appendingPathComponent("a.md").path))
    }

    func testAFolderGrantCoversFilesAndSubfoldersBelowIt() throws {
        let docs = try makeFolder("docs")
        let nested = try makeFolder("docs/img/deep")
        let store = makeStore()

        store.remember(docs)

        XCTAssertTrue(store.startAccess(coveringPath: docs.appendingPathComponent("note.md").path))
        XCTAssertTrue(store.startAccess(coveringPath: nested.appendingPathComponent("pic.png").path))
        XCTAssertTrue(store.startAccess(coveringPath: docs.path), "The folder itself is covered")
    }

    func testAGrantDoesNotCoverSiblingsOrParents() throws {
        let docs = try makeFolder("docs")
        let other = try makeFolder("docs-other")
        let store = makeStore()

        store.remember(docs)

        XCTAssertFalse(store.startAccess(coveringPath: other.appendingPathComponent("x.md").path),
                       "A folder whose name merely starts with the granted name is not covered")
        XCTAssertFalse(store.startAccess(coveringPath: directory.appendingPathComponent("x.md").path),
                       "A parent of the granted folder is not covered")
    }

    func testGrantsSurviveANewStoreOverTheSameDefaults() throws {
        let docs = try makeFolder("docs")
        makeStore().remember(docs)

        let relaunched = makeStore()

        XCTAssertTrue(relaunched.startAccess(coveringPath: docs.appendingPathComponent("note.md").path))
    }

    func testRememberingThePathAgainKeepsOneEntryAndMovesItToTheFront() throws {
        let first = try makeFolder("first")
        let second = try makeFolder("second")
        let store = makeStore()

        store.remember(first)
        store.remember(second)
        store.remember(first)

        XCTAssertEqual(store.rememberedPaths.count, 2)
        XCTAssertEqual(URL(fileURLWithPath: store.rememberedPaths[0]).lastPathComponent, "first")
    }

    func testTheOldestEntriesFallOffAtTheLimit() throws {
        let store = makeStore(limit: 2)
        let a = try makeFolder("a"), b = try makeFolder("b"), c = try makeFolder("c")

        store.remember(a)
        store.remember(b)
        store.remember(c)

        XCTAssertEqual(store.rememberedPaths.map { URL(fileURLWithPath: $0).lastPathComponent }, ["c", "b"])
    }

    func testTheMostSpecificGrantIsUsedWhenSeveralCoverAPath() throws {
        let outer = try makeFolder("outer")
        let inner = try makeFolder("outer/inner")
        let store = makeStore()

        store.remember(outer)
        store.remember(inner)

        XCTAssertTrue(store.startAccess(coveringPath: inner.appendingPathComponent("x.md").path))
        XCTAssertEqual(store.rememberedPaths.count, 2)
    }

    func testForgetAllClearsEverything() throws {
        let docs = try makeFolder("docs")
        let store = makeStore()
        store.remember(docs)

        store.forgetAll()

        XCTAssertEqual(store.rememberedPaths, [])
        XCTAssertFalse(store.startAccess(coveringPath: docs.appendingPathComponent("x.md").path))
    }

    func testAPathThatCannotBeBookmarkedIsIgnored() {
        let store = makeStore()

        store.remember(directory.appendingPathComponent("does-not-exist"))
        store.remember(URL(string: "https://example.com/x")!)

        XCTAssertEqual(store.rememberedPaths, [])
    }

    func testFolderAccessCheckIgnoresMissingFilesAndReadableFiles() throws {
        let readable = directory.appendingPathComponent("here.png")
        try "x".write(to: readable, atomically: true, encoding: .utf8)

        XCTAssertFalse(FolderAccessPrompt.isFolderAccessMissing(for: [readable]))
        XCTAssertFalse(FolderAccessPrompt.isFolderAccessMissing(for: [directory.appendingPathComponent("missing.png")]))
        XCTAssertFalse(FolderAccessPrompt.isFolderAccessMissing(for: []))
    }
}
