import Foundation

/// A file-based preference store for settings that must survive relaunches.
///
/// On macOS 26 (Tahoe), ad-hoc signed apps can no longer use App Group containers
/// because `containermanagerd` requires a valid Team ID prefix. This store replaces
/// `UserDefaults(suiteName:)` with a plist at
/// `~/Library/Application Support/BoaMarkdown/shared-preferences.plist`.
///
/// The Quick Look extension that once shared this file is gone, so the path no longer has to
/// name the real home directory. It uses the standard Application Support location, which the
/// App Sandbox redirects into the app's container; see `docs/sandbox-plan.md`. Settings saved at
/// the old real-home path by an unsandboxed build are not read by a sandboxed one.
///
/// **Thread safety:** All access is serialized through a serial DispatchQueue.
/// This matches the thread-safety guarantee of the `UserDefaults` API it replaces.
///
/// **Reload strategy:** Reads are cached and re-read when the file's modification
/// date changes.
///
/// See: upstream issue #13
public class SharedPreferenceStore {

    private static let fileName = "shared-preferences.plist"

    private var cache: [String: Any]
    private let fileURL: URL
    private let canWrite: Bool
    private var lastModificationDate: Date?
    private let queue = DispatchQueue(label: "io.github.boaworm.Markdown.SharedPreferenceStore")

    /// Creates a store backed by the default plist location.
    public convenience init() {
        self.init(fileURL: Self.defaultFileURL())
    }

    /// Creates a store backed by a specific file URL (for testing).
    public init(fileURL: URL) {
        self.fileURL = fileURL

        // Ensure the parent directory exists. Creating it fails when the store
        // location is not writable, which is why writability is checked separately.
        let dir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // Use an explicit writability check rather than inferring from directory creation,
        // since createDirectory can succeed for an existing directory even without write access.
        self.canWrite = FileManager.default.isWritableFile(atPath: dir.path)

        // Load existing preferences from file
        if let dict = NSDictionary(contentsOf: fileURL) as? [String: Any] {
            self.cache = dict
            self.lastModificationDate = Self.modificationDate(of: fileURL)
        } else {
            self.cache = [:]
            self.lastModificationDate = nil
        }
    }

    // MARK: - Reading

    public func string(forKey key: String) -> String? {
        queue.sync {
            reloadIfNeeded()
            return cache[key] as? String
        }
    }

    public func double(forKey key: String) -> Double {
        queue.sync {
            reloadIfNeeded()
            return cache[key] as? Double ?? 0
        }
    }

    public func bool(forKey key: String) -> Bool {
        queue.sync {
            reloadIfNeeded()
            return cache[key] as? Bool ?? false
        }
    }

    public func object(forKey key: String) -> Any? {
        queue.sync {
            reloadIfNeeded()
            return cache[key]
        }
    }

    public func dictionary(forKey key: String) -> [String: Any]? {
        queue.sync {
            reloadIfNeeded()
            return cache[key] as? [String: Any]
        }
    }

    public func array(forKey key: String) -> [Any]? {
        queue.sync {
            reloadIfNeeded()
            return cache[key] as? [Any]
        }
    }

    // MARK: - Writing (updates in-memory cache; persists to disk only if writable)

    public func set(_ value: String, forKey key: String) {
        queue.sync { cache[key] = value }
    }

    public func set(_ value: Bool, forKey key: String) {
        queue.sync { cache[key] = value }
    }

    public func set(_ value: Double, forKey key: String) {
        queue.sync { cache[key] = value }
    }

    public func set(_ value: [String: Any], forKey key: String) {
        queue.sync { cache[key] = value }
    }

    public func set(_ value: [Any], forKey key: String) {
        queue.sync { cache[key] = value }
    }

    public func setNil(forKey key: String) {
        queue.sync { _ = cache.removeValue(forKey: key) }
    }

    public func removeObject(forKey key: String) {
        queue.sync { _ = cache.removeValue(forKey: key) }
    }

    /// Flush in-memory cache to disk. No-op when the store is read-only.
    @discardableResult
    public func synchronize() -> Bool {
        queue.sync { _synchronizeUnsafe() }
    }

    // MARK: - Private

    /// `Application Support/BoaMarkdown` in the user's library. Unsandboxed this is
    /// `~/Library/Application Support/BoaMarkdown`; under the App Sandbox the system maps the same
    /// call into the app's container, which is the only place a sandboxed app may write.
    static func applicationSupportDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        return base.appendingPathComponent("BoaMarkdown", isDirectory: true)
    }

    private static func defaultFileURL() -> URL {
        applicationSupportDirectory().appendingPathComponent(fileName)
    }

    /// Must be called within `queue.sync`. Writes cache to disk.
    @discardableResult
    private func _synchronizeUnsafe() -> Bool {
        guard canWrite else { return false }

        // Validate that all values are plist-serializable before writing
        guard PropertyListSerialization.propertyList(
            cache, isValidFor: .xml
        ) else {
            NSLog("[SharedPreferenceStore] Cache contains non-plist-serializable values — write skipped. " +
                  "Keys: %@", Array(cache.keys).joined(separator: ", "))
            return false
        }

        let success = (cache as NSDictionary).write(to: fileURL, atomically: true)
        if success {
            lastModificationDate = Self.modificationDate(of: fileURL)
        } else {
            NSLog("[SharedPreferenceStore] Failed to write preferences to %@", fileURL.path)
        }
        return success
    }

    /// Must be called within `queue.sync`. Re-reads only if the modification date changed.
    private func reloadIfNeeded() {
        let currentMod = Self.modificationDate(of: fileURL)
        guard currentMod != lastModificationDate else { return }
        reloadFromDisk()
        lastModificationDate = currentMod
    }

    /// Must be called within `queue.sync`.
    private func reloadFromDisk() {
        if let dict = NSDictionary(contentsOf: fileURL) as? [String: Any] {
            cache = dict
        } else if FileManager.default.fileExists(atPath: fileURL.path) {
            // File exists but could not be parsed — likely corrupted
            NSLog("[SharedPreferenceStore] WARNING: plist at %@ exists but failed to parse — " +
                  "keeping cached values", fileURL.path)
        }
    }

    private static func modificationDate(of url: URL) -> Date? {
        try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
    }
}
