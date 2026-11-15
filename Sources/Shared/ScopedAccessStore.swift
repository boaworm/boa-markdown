import Foundation

/// Remembers access the user has granted, so it survives relaunches under the App Sandbox.
///
/// A sandboxed app only reaches a file or folder the user handed to it (Finder, the Open panel,
/// drag and drop), and only until it quits. Security-scoped bookmarks turn that one-time grant
/// into something the app can resume: store one when access is granted, and start it again
/// before touching the path later.
///
/// Without the sandbox every call still works (bookmarks resolve and `startAccessing` is a no-op),
/// so the same code runs in unsandboxed development builds.
final class ScopedAccessStore {
    static let shared = ScopedAccessStore()

    private let defaults: UserDefaults
    private let key: String
    private let limit: Int
    private let lock = NSLock()
    /// Scopes started in this run, so each is started once and never leaks twice.
    private var started: Set<String> = []

    init(defaults: UserDefaults = .standard, key: String = "ScopedAccessBookmarks.v1", limit: Int = 200) {
        self.defaults = defaults
        self.key = key
        self.limit = max(1, limit)
    }

    private struct Entry {
        let path: String
        let bookmark: Data
    }

    private func load() -> [Entry] {
        let raw = defaults.array(forKey: key) as? [[String: Any]] ?? []
        return raw.compactMap { item in
            guard let path = item["path"] as? String, let data = item["bookmark"] as? Data else { return nil }
            return Entry(path: path, bookmark: data)
        }
    }

    private func save(_ entries: [Entry]) {
        defaults.set(entries.prefix(limit).map { ["path": $0.path, "bookmark": $0.bookmark] }, forKey: key)
    }

    private static func normalized(_ url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }

    /// Stores a bookmark for a file or folder the app can reach right now.
    /// The newest entry for a path replaces the old one; the oldest entries fall off at the limit.
    func remember(_ url: URL) {
        guard url.isFileURL,
              let data = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        else { return }
        let path = Self.normalized(url)
        lock.lock(); defer { lock.unlock() }
        save([Entry(path: path, bookmark: data)] + load().filter { $0.path != path })
    }

    /// Starts access using the stored bookmark for `path` itself or its nearest ancestor.
    /// Returns true when such a bookmark exists and its scope is active (now or from before).
    @discardableResult
    func startAccess(coveringPath path: String) -> Bool {
        let target = URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path
        lock.lock(); defer { lock.unlock() }

        let covering = load()
            .filter { target == $0.path || target.hasPrefix($0.path.hasSuffix("/") ? $0.path : $0.path + "/") }
            .max { $0.path.count < $1.path.count }
        guard let entry = covering else { return false }
        if started.contains(entry.path) { return true }

        var stale = false
        guard let url = try? URL(resolvingBookmarkData: entry.bookmark, options: .withSecurityScope,
                                 relativeTo: nil, bookmarkDataIsStale: &stale),
              url.startAccessingSecurityScopedResource() else { return false }
        started.insert(entry.path)

        if stale, let fresh = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
            save([Entry(path: entry.path, bookmark: fresh)] + load().filter { $0.path != entry.path })
        }
        return true
    }

    /// Paths with a stored bookmark, newest first.
    var rememberedPaths: [String] { lock.lock(); defer { lock.unlock() }; return load().map(\.path) }

    func forgetAll() { lock.lock(); defer { lock.unlock() }; defaults.removeObject(forKey: key) }
}
