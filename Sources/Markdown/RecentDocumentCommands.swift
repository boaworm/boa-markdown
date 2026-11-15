import SwiftUI
import AppKit

/// SwiftUI owns its document controller. Keep durable history in the app menu
/// rather than replacing SwiftUI's private controller and breaking DocumentGroup.
struct RecentDocumentCommands: Commands {
    @ObservedObject private var history = RecentDocumentHistory.shared

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button(NSLocalizedString("New Document", comment: "File menu")) {
                NSDocumentController.shared.newDocument(nil)
            }.keyboardShortcut("n")
            Button(NSLocalizedString("Open…", comment: "File menu")) {
                NSDocumentController.shared.openDocument(nil)
            }.keyboardShortcut("o")
            Menu(NSLocalizedString("Open Recent", comment: "File menu")) {
                ForEach(history.urls, id: \.self) { url in
                    Button(url.lastPathComponent) { open(url) }
                        .help(url.path)
                }
                Divider()
                Button(NSLocalizedString("Clear Menu", comment: "Recent documents menu")) {
                    history.clear()
                    NSDocumentController.shared.clearRecentDocuments(nil)
                }.disabled(history.urls.isEmpty)
            }
            Button(NSLocalizedString("Allow Access to Document Folder…", comment: "File menu")) {
                allowAccessToDocumentFolder()
            }
        }
    }

    /// Lets the user grant (or grant again) the folder of the document in front, so its images
    /// and linked files can be read under the App Sandbox.
    private func allowAccessToDocumentFolder() {
        guard let fileURL = NSDocumentController.shared.currentDocument?.fileURL else { return }
        let reason = "BoaMarkdown needs access to this folder to show its images and open the files it links to."
        if FolderAccessPrompt.request(forFolder: fileURL.deletingLastPathComponent(), reason: reason, force: true) {
            NotificationCenter.default.post(name: .reloadFile, object: nil)
        }
    }

    private func open(_ url: URL) {
        ScopedAccessStore.shared.startAccess(coveringPath: url.path)
        NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, error in
            if error != nil {
                FailureNotice.alert(.fileRead, recoveryTitle: "Choose Another File", recovery: {
                    NSDocumentController.shared.openDocument(nil)
                })
            } else { history.record(url) }
        }
    }
}
