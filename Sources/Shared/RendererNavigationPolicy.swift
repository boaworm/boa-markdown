import WebKit
import os.log

/// What the web view may navigate to. The page's Content-Security-Policy does not cover top-level
/// navigation, and the app holds the outgoing-network entitlement `WKWebView` needs to start, so
/// anything that is not the bundled renderer is refused here.
enum RendererNavigationPolicy: Equatable {
    case allow
    case openInBrowser(URL)
    case cancel

    static func decision(for url: URL?, isLinkActivated: Bool) -> RendererNavigationPolicy {
        guard let url, let scheme = url.scheme?.lowercased() else { return .cancel }
        if scheme == RendererBundleSchemeHandler.scheme && url.host == "bundle" { return .allow }
        // Only a link the user clicked may leave the app, and only to the browser.
        if isLinkActivated && (scheme == "http" || scheme == "https") { return .openInBrowser(url) }
        return .cancel
    }
}

/// Blocks every remote load inside the web view, below the page's own Content-Security-Policy.
enum RendererNetworkBlocklist {
    static let identifier = "io.github.boaworm.Markdown.network-blocklist.v1"
    // Content-blocker patterns have no alternation, so each scheme family is its own rule.
    static let blockedURLFilters = ["^https?://", "^wss?://", "^ftp://"]

    static var encodedRules: String {
        let rules = blockedURLFilters.map { ["trigger": ["url-filter": $0], "action": ["type": "block"]] }
        let data = (try? JSONSerialization.data(withJSONObject: rules)) ?? Data("[]".utf8)
        return String(decoding: data, as: UTF8.self)
    }

    static func install(on userContentController: WKUserContentController) {
        WKContentRuleListStore.default().compileContentRuleList(forIdentifier: identifier,
                                                                encodedContentRuleList: encodedRules) { list, error in
            DispatchQueue.main.async {
                if let list {
                    userContentController.add(list)
                } else {
                    os_log("Network block list unavailable: %{public}@",
                           log: OSLog(subsystem: "io.github.boaworm.Markdown", category: "RendererNetworkBlocklist"),
                           type: .error, error?.localizedDescription ?? "unknown")
                }
            }
        }
    }
}
