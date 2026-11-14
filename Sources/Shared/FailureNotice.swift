import AppKit

/// What went wrong, in terms a reader can act on. Nothing here is recorded or sent anywhere.
enum FailureKind: String, CaseIterable {
    case copy, fileRead, fileTooLarge, reload, exportHTML, exportPDF, renderer, rendererResources, source
    case math, search, images, previewLimit, link, browser

    var title: String {
        switch self {
        case .copy: return "Text could not be copied"
        case .fileRead, .fileTooLarge: return "Document could not be opened"
        case .reload: return "Document could not be reloaded"
        case .exportHTML, .exportPDF: return "Export could not be completed"
        case .rendererResources: return "Preview could not start"
        case .renderer, .source: return "Document could not be displayed"
        case .math: return "This formula could not be displayed"
        case .search: return "Search could not be completed"
        case .images: return "Some images could not be displayed"
        case .previewLimit: return "This preview is incomplete"
        case .link, .browser: return "The destination could not be opened"
        }
    }

    var guidance: String {
        switch self {
        case .copy: return "Select the text to copy it manually, or try again."
        case .fileRead: return "Choose a readable UTF-8 Markdown file, or open it in your editor to check it."
        case .fileTooLarge: return "Open this document in your editor, or split it into smaller files before trying again."
        case .reload: return "Try reloading again when the file is available. Your current document has not been discarded."
        case .exportHTML, .exportPDF: return "Try exporting again and choose another writable folder."
        case .rendererResources: return "The renderer resources are missing. Rebuild or reinstall the app, or open the document in your editor."
        case .renderer, .source: return "Try reloading the preview, or open the document in your editor."
        case .math: return "Check the formula source in your editor. The rest of the document is still available."
        case .search: return "Check the search expression, or open the document in the app and press Command-F."
        case .images, .previewLimit: return "Open the document in the app to read beyond the preview limits."
        case .link: return "The link may point to a file that is not on this Mac, or to a path that is not relative to the document."
        case .browser: return "Open the destination in your browser or editor."
        }
    }
}

/// Identifies one rendered document so that late callbacks from a previous render are ignored.
final class RenderScope {
    private(set) var scope = UUID()
    func beginDocument() -> String { scope = UUID(); return scope.uuidString }
}

/// Native message shown over a web view that failed, with an optional retry action.
final class FailureNotice: NSView {
    private let recovery: (() -> Void)?

    init(kind: FailureKind, recoveryTitle: String? = nil, recovery: (() -> Void)? = nil) {
        self.recovery = recovery
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel(NSLocalizedString(kind.title, comment: "Failure title"))
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        layer?.cornerRadius = 8
        let message = NSTextField(wrappingLabelWithString:
            NSLocalizedString(kind.title, comment: "Failure title") + ". " + NSLocalizedString(kind.guidance, comment: "Failure guidance"))
        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.spacing = 8
        if let recoveryTitle, recovery != nil {
            buttons.addArrangedSubview(NSButton(title: NSLocalizedString(recoveryTitle, comment: "Failure recovery"), target: self, action: #selector(recover)))
        }
        buttons.addArrangedSubview(NSButton(title: NSLocalizedString("Close", comment: "Close"), target: self, action: #selector(close)))
        let stack = NSStackView(views: [message, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }

    required init?(coder: NSCoder) { nil }

    @objc private func recover() { removeFromSuperview(); recovery?() }
    @objc private func close() { removeFromSuperview() }

    /// Replaces any notice already shown on `view`.
    @discardableResult
    static func attach(to view: NSView, kind: FailureKind, recoveryTitle: String? = nil, recovery: (() -> Void)? = nil) -> FailureNotice {
        view.subviews.compactMap { $0 as? FailureNotice }.forEach { $0.removeFromSuperview() }
        let notice = FailureNotice(kind: kind, recoveryTitle: recoveryTitle, recovery: recovery)
        notice.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(notice)
        NSLayoutConstraint.activate([
            notice.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            notice.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            notice.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -32),
            notice.widthAnchor.constraint(greaterThanOrEqualToConstant: 320)
        ])
        return notice
    }

    /// Modal alternative for failures that have no web view to attach to.
    static func alert(_ kind: FailureKind, recoveryTitle: String? = nil, recovery: (() -> Void)? = nil) {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString(kind.title, comment: "Failure title")
        alert.informativeText = NSLocalizedString(kind.guidance, comment: "Failure guidance")
        let hasRecovery = recoveryTitle != nil && recovery != nil
        if let recoveryTitle, hasRecovery { alert.addButton(withTitle: NSLocalizedString(recoveryTitle, comment: "Failure recovery")) }
        alert.addButton(withTitle: NSLocalizedString("Close", comment: "Close"))
        if alert.runModal() == .alertFirstButtonReturn, hasRecovery { recovery?() }
    }
}

/// Document read errors presented by the system document machinery.
struct DocumentReadFailure: LocalizedError, CustomNSError {
    let kind: FailureKind
    init(kind: FailureKind, error: Error) { self.kind = kind }
    var errorDescription: String? { NSLocalizedString(kind.title, comment: "Failure title") }
    var recoverySuggestion: String? { NSLocalizedString(kind.guidance, comment: "Failure guidance") }
    static var errorDomain: String { "DocumentRead" }
    var errorCode: Int { kind == .fileTooLarge ? CocoaError.fileReadTooLarge.rawValue : CocoaError.fileReadCorruptFile.rawValue }
}
