import Foundation
import os.log
import WebKit

/// Opt-in diagnostics that name the subresource a page failed to load and the document that
/// requested it. WebKit's own failure line is privacy-redacted, so it is not actionable.
///
/// Enable for one run: `BOA_DIAGNOSE_SUBRESOURCES=1 ./BoaMarkdown.app/Contents/MacOS/BoaMarkdown`
/// Enable persistently: `defaults write <bundle id> BOADiagnoseSubresources -bool true`
enum SubresourceDiagnostics {
    static let environmentKey = "BOA_DIAGNOSE_SUBRESOURCES"
    static let defaultsKey = "BOADiagnoseSubresources"
    static let messageHandlerName = "subresourceDiagnostics"
    static let reportedURLLimit = 50
    static let loggedCharacterLimit = 400

    private static let disabledValues: Set<String> = ["", "0", "false", "no", "off"]

    static func isEnabled(environment: [String: String] = ProcessInfo.processInfo.environment,
                          defaults: UserDefaults = .standard) -> Bool {
        if let value = environment[environmentKey]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            return !disabledValues.contains(value)
        }
        return defaults.bool(forKey: defaultsKey)
    }

    static func userScript() -> WKUserScript {
        WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true)
    }

    /// Resource load errors reach the host only as an `error` event on the failing element;
    /// WKNavigationDelegate reports navigations, not subresources.
    static let source = """
    (function () {
      if (window.__boaSubresourceDiagnostics) { return; }
      window.__boaSubresourceDiagnostics = true;
      var seen = Object.create(null);
      var count = 0;
      function post(url, tag) {
        if (!url || seen[url] || count >= \(reportedURLLimit)) { return; }
        seen[url] = true;
        count += 1;
        try {
          window.webkit.messageHandlers.\(messageHandlerName).postMessage(JSON.stringify({
            url: String(url),
            tag: String(tag || '')
          }));
        } catch (e) {}
      }
      window.addEventListener('error', function (event) {
        var target = event && event.target;
        if (!target || target === window || target === document) { return; }
        post(target.currentSrc || target.src || target.href, target.tagName);
      }, true);
    })();
    """

    static func report(_ body: Any?, documentURL: URL?, logger: OSLog) {
        let documentPath = documentURL?.path ?? "<unsaved document>"
        for failure in failedURLs(from: body) {
            os_log("Subresource failed: %{public}@ [%{public}@] requested by %{public}@",
                   log: logger, type: .info,
                   sanitized(failure.url), sanitized(failure.tag), documentPath)
        }
    }

    static func failedURLs(from body: Any?) -> [(url: String, tag: String)] {
        if let dictionary = body as? [String: Any] {
            guard let url = dictionary["url"] as? String, !url.isEmpty else { return [] }
            return [(url: url, tag: dictionary["tag"] as? String ?? "")]
        }
        guard let text = body as? String, !text.isEmpty else { return [] }
        let decoded = text.data(using: .utf8).flatMap { try? JSONSerialization.jsonObject(with: $0) }
        guard let dictionary = decoded as? [String: Any] else {
            return [(url: text, tag: "")]
        }
        guard let url = dictionary["url"] as? String, !url.isEmpty else { return [] }
        return [(url: url, tag: dictionary["tag"] as? String ?? "")]
    }

    /// Page-supplied text goes into the log, so flatten control characters and bound the length.
    static func sanitized(_ value: String) -> String {
        var characters: [Character] = []
        characters.reserveCapacity(value.count)
        for scalar in value.unicodeScalars {
            characters.append(CharacterSet.controlCharacters.contains(scalar) ? " " : Character(scalar))
        }
        let flattened = characters.reduce(into: "") { result, character in
            if character == " " {
                if result.last != " " { result.append(character) }
            } else {
                result.append(character)
            }
        }
        if flattened.count <= loggedCharacterLimit { return flattened }
        return String(flattened.prefix(loggedCharacterLimit)) + "…"
    }
}
