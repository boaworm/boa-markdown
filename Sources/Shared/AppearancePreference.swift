import Foundation
import SwiftUI
import AppKit

public enum AppearanceMode: String, CaseIterable, Identifiable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .light: return NSLocalizedString("Light", comment: "Light appearance mode")
        case .dark: return NSLocalizedString("Dark", comment: "Dark appearance mode")
        case .system: return NSLocalizedString("System", comment: "System appearance mode")
        }
    }
    
    public var nsAppearance: NSAppearance? {
        switch self {
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        case .system: return nil // System handles it (nil implies inherited)
        }
    }
}

public enum ContentsSidebarSide: String, CaseIterable, Identifiable {
    case left, right
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .left: return NSLocalizedString("Left", comment: "Contents position")
        case .right: return NSLocalizedString("Right", comment: "Contents position")
        }
    }
}

public class AppearancePreference: ObservableObject {
    public static let shared = AppearancePreference()
    
    // Key for UserDefaults
    private let key = "preferredAppearanceMode"
    private let hostWindowFrameKey = "hostWindowFrame"
    private let zoomLevelKey = "markdownZoomLevel"
    private let scrollPositionsKey = "markdownScrollPositions"
    
    // File-based store for settings that must survive relaunches.
    // Replaces App Group UserDefaults which fails on macOS 26 (Tahoe) for ad-hoc signed apps.
    // See: upstream issue #13
    private let sharedStore: SharedPreferenceStore
    private var pendingSyncWorkItem: DispatchWorkItem?

    /// Backing store for currentMode — @Published ensures SwiftUI views (including
    /// the Settings scene) reliably re-render when the value changes.
    @Published private var _currentMode: AppearanceMode = .system

    public var currentMode: AppearanceMode {
        get { _currentMode }
        set {
            _currentMode = newValue
            sharedStore.set(newValue.rawValue, forKey: key)
            scheduleSyncToSharedStore()
        }
    }
    
    public var hostWindowFrame: CGRect? {
        get {
            guard let dict = localStore.dictionary(forKey: hostWindowFrameKey) else { return nil }
            return Self.hostWindowFrame(from: dict)
        }
        set {
            if let v = newValue {
                localStore.set(["x": v.origin.x, "y": v.origin.y, "w": v.width, "h": v.height], forKey: hostWindowFrameKey)
            } else {
                localStore.removeObject(forKey: hostWindowFrameKey)
            }
            localStore.synchronize()
        }
    }

    static func hostWindowFrame(from dict: [String: Any]) -> CGRect {
        CGRect(
            x: numericValue(for: "x", in: dict),
            y: numericValue(for: "y", in: dict),
            width: numericValue(for: "w", in: dict),
            height: numericValue(for: "h", in: dict)
        )
    }

    private static func numericValue(for key: String, in dict: [String: Any]) -> Double {
        if let value = dict[key] as? NSNumber {
            return value.doubleValue
        }

        if let value = dict[key] as? Int {
            return Double(value)
        }

        if let value = dict[key] as? CGFloat {
            return Double(value)
        }

        if let value = dict[key] as? String, let number = Double(value) {
            return number
        }

        return dict[key] as? Double ?? 0
    }

    public var zoomLevel: Double {
        get {
            let level = localStore.double(forKey: zoomLevelKey)
            return level == 0 ? 1.0 : level
        }
        set {
            localStore.set(newValue, forKey: zoomLevelKey)
            localStore.synchronize()
        }
    }
    
    private let baseFontSizeKey = "baseFontSize"
    private let codeHighlightThemeKey = "codeHighlightTheme"
    private let enableKatexKey = "enableKatex"
    private let enableEmojiKey = "enableEmoji"
    private let collapseBlockquotesByDefaultKey = "collapseBlockquotesByDefault"
    private let contentsSideKey = "contentsSide"
    private let showCopyButtonsKey = "showCopyButtons"
    private let showLineNumbersKey = "showLineNumbers"

    public var baseFontSize: Double {
        get {
            let v = sharedStore.double(forKey: baseFontSizeKey)
            return v == 0 ? 14 : v
        }
        set {
            objectWillChange.send()
            sharedStore.set(newValue, forKey: baseFontSizeKey)
            scheduleSyncToSharedStore()
        }
    }

    public var codeHighlightTheme: String {
        get { sharedStore.string(forKey: codeHighlightThemeKey) ?? "default" }
        set {
            objectWillChange.send()
            sharedStore.set(newValue, forKey: codeHighlightThemeKey)
            scheduleSyncToSharedStore()
        }
    }

    public var enableKatex: Bool {
        get {
            guard sharedStore.object(forKey: enableKatexKey) != nil else { return true }
            return sharedStore.bool(forKey: enableKatexKey)
        }
        set {
            objectWillChange.send()
            sharedStore.set(newValue, forKey: enableKatexKey)
            scheduleSyncToSharedStore()
        }
    }

    public var enableEmoji: Bool {
        get {
            guard sharedStore.object(forKey: enableEmojiKey) != nil else { return true }
            return sharedStore.bool(forKey: enableEmojiKey)
        }
        set {
            objectWillChange.send()
            sharedStore.set(newValue, forKey: enableEmojiKey)
            scheduleSyncToSharedStore()
        }
    }

    public var collapseBlockquotesByDefault: Bool {
        get {
            guard sharedStore.object(forKey: collapseBlockquotesByDefaultKey) != nil else { return false }
            return sharedStore.bool(forKey: collapseBlockquotesByDefaultKey)
        }
        set {
            objectWillChange.send()
            sharedStore.set(newValue, forKey: collapseBlockquotesByDefaultKey)
            scheduleSyncToSharedStore()
        }
    }

    public var contentsSide: ContentsSidebarSide {
        get { ContentsSidebarSide(rawValue: sharedStore.string(forKey: contentsSideKey) ?? "right") ?? .right }
        set {
            objectWillChange.send()
            sharedStore.set(newValue.rawValue, forKey: contentsSideKey)
            scheduleSyncToSharedStore()
        }
    }

    public var showLineNumbers: Bool {
        get {
            guard sharedStore.object(forKey: showLineNumbersKey) != nil else { return false }
            return sharedStore.bool(forKey: showLineNumbersKey)
        }
        set {
            objectWillChange.send()
            sharedStore.set(newValue, forKey: showLineNumbersKey)
            scheduleSyncToSharedStore()
        }
    }

    public var showCopyButtons: Bool {
        get {
            guard sharedStore.object(forKey: showCopyButtonsKey) != nil else { return true }
            return sharedStore.bool(forKey: showCopyButtonsKey)
        }
        set {
            objectWillChange.send()
            sharedStore.set(newValue, forKey: showCopyButtonsKey)
            scheduleSyncToSharedStore()
        }
    }

    // Settings that stay in app defaults rather than the shared plist
    // (zoom level, scroll positions, window sizes)
    private let localStore: UserDefaults

    public convenience init() {
        self.init(
            sharedStore: SharedPreferenceStore(alwaysReload: false),
            localStore: UserDefaults.standard,
            migrateFromAppGroup: true
        )
    }

    init(sharedStore: SharedPreferenceStore, localStore: UserDefaults, migrateFromAppGroup: Bool) {
        self.sharedStore = sharedStore
        self.localStore = localStore

        // Migrate preferences from pre-Tahoe App Group UserDefaults on first launch.
        // No-op when the shared store is read-only.
        if migrateFromAppGroup {
            sharedStore.migrateFromAppGroupIfNeeded()
        }

        // Sync @Published backing store from disk so views have the correct initial value.
        let raw = sharedStore.string(forKey: key) ?? AppearanceMode.system.rawValue
        self._currentMode = AppearanceMode(rawValue: raw) ?? .system
    }

    /// Coalesces rapid preference changes into a single disk write.
    /// Writes after a 0.3s debounce, preventing 5+ writes when changing multiple settings.
    private func scheduleSyncToSharedStore() {
        pendingSyncWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.sharedStore.synchronize()
        }
        pendingSyncWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }

    /// Force-flush any pending shared preference writes to disk immediately.
    /// Called from applicationWillTerminate to ensure nothing is lost.
    public func flushSharedPreferences() {
        pendingSyncWorkItem?.cancel()
        pendingSyncWorkItem = nil
        sharedStore.synchronize()
    }
    
    func observePreferenceChanges() {
        // Keep the @Published theme in sync with an observed external write.
        let mode = AppearanceMode(rawValue: sharedStore.string(forKey: key) ?? "system") ?? .system
        if mode != _currentMode { _currentMode = mode }
    }

    func setAppearance(_ mode: AppearanceMode) {
        _currentMode = mode
        sharedStore.set(mode.rawValue, forKey: key)
        scheduleSyncToSharedStore()
    }

    private let maxScrollPositions = 100
    
    private struct ScrollPosition {
        let path: String
        let scrollY: Double
        
        init(path: String, scrollY: Double) {
            self.path = path
            self.scrollY = scrollY
        }
        
        init?(dict: [String: Any]) {
            guard let path = dict["path"] as? String,
                  let scrollY = dict["scrollY"] as? Double else {
                return nil
            }
            self.path = path
            self.scrollY = scrollY
        }
        
        func toDictionary() -> [String: Any] {
            return ["path": path, "scrollY": scrollY]
        }
    }
    
    private var scrollPositions: [ScrollPosition] {
        get {
            guard let array = localStore.array(forKey: scrollPositionsKey) as? [[String: Any]] else {
                return []
            }
            return array.compactMap { ScrollPosition(dict: $0) }
        }
        set {
            let array = newValue.map { $0.toDictionary() }
            localStore.set(array, forKey: scrollPositionsKey)
            localStore.synchronize()
        }
    }
    
    public func getScrollPosition(for filePath: String) -> Double? {
        return scrollPositions.first { $0.path == filePath }?.scrollY
    }
    
    public func setScrollPosition(for filePath: String, value: Double) {
        var positions = scrollPositions
        
        positions.removeAll { $0.path == filePath }
        positions.insert(ScrollPosition(path: filePath, scrollY: value), at: 0)
        
        if positions.count > maxScrollPositions {
            positions = Array(positions.prefix(maxScrollPositions))
        }
        
        scrollPositions = positions
    }
    
    public func clearScrollPositions() {
        localStore.removeObject(forKey: scrollPositionsKey)
        localStore.synchronize()
    }
    
    // Helper to apply appearance to a view
    public func apply(to view: NSView) {
        if let appearance = currentMode.nsAppearance {
            view.appearance = appearance
        } else {
            view.appearance = nil // Reset to system
        }
    }
}
