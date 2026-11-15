import AppKit

/// Asks the user to allow access to a document's folder.
///
/// Under the App Sandbox, opening a document grants access to that one file, not to the images
/// and linked files beside it. This panel is the standard way to widen that: the user picks the
/// folder once, and the choice is remembered as a security-scoped bookmark.
enum FolderAccessPrompt {
    /// Folders the user has already been asked about in this run, so a declined prompt does
    /// not return on every render. The File menu item asks again on demand.
    private static var askedThisRun: Set<String> = []

    /// True when something next to the document exists but cannot be read, which is what a
    /// sandboxed app sees for a folder it has not been given.
    static func isFolderAccessMissing(for urls: [URL]) -> Bool {
        let manager = FileManager.default
        return urls.contains { manager.fileExists(atPath: $0.path) && !manager.isReadableFile(atPath: $0.path) }
    }

    /// Shows the panel unless this folder was already offered in this run (or `force` is set).
    /// Returns true when the user granted access.
    @MainActor
    @discardableResult
    static func request(forFolder folder: URL, reason: String, force: Bool = false) -> Bool {
        let path = folder.standardizedFileURL.path
        guard force || askedThisRun.insert(path).inserted else { return false }

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = folder
        panel.title = "Allow Access to Folder"
        panel.message = reason
        panel.prompt = "Allow Access"
        guard panel.runModal() == .OK, let granted = panel.url else { return false }

        ScopedAccessStore.shared.remember(granted)
        ScopedAccessStore.shared.startAccess(coveringPath: granted.path)
        return true
    }
}
