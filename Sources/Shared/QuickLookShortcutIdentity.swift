import Foundation

struct QuickLookShortcutEvidence {
    var permissionGranted: Bool
    var finderFrontmost: Bool
    var focusedWindow: Bool
    var identifier: String
    var buttonRole: Bool
    var pressAction: Bool
    var extensionSignatureValid: Bool
    var extensionIdentifier: String
    var expectedExecutable: Bool
}

enum QuickLookShortcutIdentity {
    static let prefix = "io.github.boaworm.Markdown.QuickLook.search."

    static func identifier(for viewID: UUID) -> String { prefix + viewID.uuidString }

    static func viewID(from identifier: String) -> UUID? {
        guard identifier.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(identifier.dropFirst(prefix.count)))
    }

    static func isEligible(_ evidence: QuickLookShortcutEvidence) -> Bool {
        evidence.permissionGranted && evidence.finderFrontmost && evidence.focusedWindow
            && viewID(from: evidence.identifier) != nil && evidence.buttonRole
            && evidence.pressAction && evidence.extensionSignatureValid
            && evidence.extensionIdentifier == "io.github.boaworm.Markdown.QuickLook"
            && evidence.expectedExecutable
    }
}
