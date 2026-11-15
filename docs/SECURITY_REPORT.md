# Security Review Report — BoaMarkdown (FluxMarkdown)

**Original review date:** 2026-11-14
**Reviewer:** Automated security review (3 subagents + manual code review)
**Version reviewed:** v1.50.828
**Project:** boa-markdown — a stripped-down, local-only Markdown viewer for macOS (app + Finder Quick Look extension)

> **Status update.** The review below (sections 1 to 6) was written against an older code base: a
> TypeScript renderer (`web-renderer/`), a Quick Look extension, an XPC launcher, and the Vega, Graphviz
> and Typst engines. Most of that has since been removed. **Read "Current status" first.** The original
> text is kept unchanged below it as a record, so its file paths and line numbers no longer match the tree.

---

## Current status

Checked on 2026-11-14 against the code of this branch, plus the separate `feat/mermaid-diagrams` branch
for the findings that mention Mermaid (15 and N3), which is not merged yet. Each finding was checked by
reading the current code or searching for the pattern; "not re-verified" marks the ones I could not confirm.
No dynamic testing was done. Status values:

| Status | Meaning |
|--------|---------|
| Open | The issue still exists in the current code |
| Partly addressed | Reduced or mitigated, but not closed |
| Fixed | Closed by a change in the current code |
| Removed | The affected code no longer exists |
| Accepted | Known and intentional (debug-only or non-sensitive) |
| Holds | A positive observation that is still true |

### Summary

| Status | Count | Findings |
|--------|-------|----------|
| Removed (includes fixed by removal) | 19 | 2, 5, 7, 10, 16, 21, 22, 23, 28, 34, 35, 36, 37, 40, 45, 46, 48, 49, 51 |
| Fixed | 7 | 1, 6, 17, 26, 27, 29, 31 |
| Partly addressed | 9 | 9, 13, 14, 15, 32, 50, 52, 53, 54 |
| Holds (positive) | 1 | 25 |
| Accepted | 2 | 4, 12 |
| Open | 15 | 3, 8, 11, 18, 20, 24, 30, 33, 38, 39, 41, 42, 43, 44, 47 |
| Not re-verified | 1 | 19 |
| **Total** | **54** | |

The two CRITICAL findings (1 and 52) shared one root cause: the main app ran unsandboxed. The App Sandbox is now enabled, so 1 is Fixed and 52 is Partly addressed: files are confined, but the sandbox does not block the network because `WKWebView` needs the `network.client` entitlement to start.
Of the original HIGH findings, 2, 7, 26, 27, 28 and 29 are Fixed or Removed. Findings 6, 13 and 44 remain Open, and I now rate all three lower (see the table).

### Status of every finding

"Now" is my current severity for findings that are still Open; it can differ from the original rating.

| # | Original | Status | Now | Evidence and notes |
|---|----------|--------|-----|--------------------|
| 1 | CRITICAL | Fixed | n/a | `com.apple.security.app-sandbox` is enabled in both `Markdown.entitlements` and `MarkdownRelease.entitlements`, with read-write user-selected files, app-scope bookmarks and `network.client` (needed for `WKWebView` to start). Folder access is granted once per folder through `FolderAccessPrompt` and remembered by `ScopedAccessStore`. Details in `docs/sandbox-plan.md`. Checked by hand: the app launches and renders a document; Open Recent after a relaunch, exports and the folder prompt still need a manual check. |
| 2 | HIGH | Removed | n/a | Quick Look extension deleted. |
| 3 | MEDIUM | Open | Medium | `com.apple.security.cs.allow-jit` is in both remaining entitlement files. Likely unnecessary for `WKWebView` (not verified by removing it). Release also has `ENABLE_HARDENED_RUNTIME = NO` (see N2). |
| 4 | LOW | Accepted | n/a | `get-task-allow` is in the Debug entitlements only. |
| 5 | MEDIUM | Removed | n/a | `Sources/Markdown/main.swift` now handles only `--export-pdf`. That mode's own input handling was not reviewed. |
| 6 | HIGH | Fixed | n/a | "Open in External Editor" now uses `NSWorkspace.open(_:withApplicationAt:configuration:)` with the default plain-text editor. The app no longer spawns any process. |
| 7 | HIGH | Removed | n/a | `QuickLookRegistration.swift` deleted. |
| 8 | MEDIUM | Open | Low | Main-app navigation delegate still returns `.allow` for anything it does not recognise (`MarkdownWebView.swift:1013-1029`). The Quick Look half is gone. |
| 9 | MEDIUM | Partly addressed | Low | Origin check holds (`RendererBridgePolicy`). `blockCopy` is validated (id at most 32 bytes, text at most 4 MiB, `BlockCopyBridge.swift:17-20`). The `logger` and `linkClicked` handlers have no length cap (`MarkdownWebView.swift:684-708`). |
| 10 | MEDIUM | Removed | n/a | No `<base>` tag is created by the renderer. |
| 11 | LOW | Open | Low | Interpolated JavaScript remains at `MarkdownWebView.swift:435, 503, 532`. Values are enum raw values and counters. Use `callAsyncJavaScript(arguments:)`. |
| 12 | LOW | Accepted | n/a | Web Inspector is enabled only under `#if DEBUG`. |
| 13 | HIGH | Partly addressed | Low | `markdownpreview://open?path=` still accepts any absolute path with any extension in its parser (`DocumentPosition.swift:31-37`, `MarkdownApp.swift:35-60`), but under the sandbox the app can only open paths it can already read, so other paths fail. Still worth restricting to supported document extensions. |
| 14 | MEDIUM | Partly addressed | Low | `http(s)` links still open in the browser without confirmation (standard viewer behaviour). Local links no longer launch anything without asking; see N1. |
| 15 | MEDIUM | Partly addressed | Low | `.mmd` is still wrapped as a mermaid fence (`BoundedFileReader.swift:36`) and is now drawn by the vendored Mermaid in `strict` mode, under the CSP. |
| 16 | POSITIVE | Removed | n/a | XPC service deleted; no longer applicable. |
| 17 | MEDIUM | Fixed | n/a | The `getpwuid` lookup is gone. The settings plist uses the standard Application Support location, which the sandbox maps into the app's container, so other processes running as the user can no longer read or write it. |
| 18 | LOW | Open | Low | Recent document paths are still in `UserDefaults` (`RecentDocumentHistory.swift`, key `BoaRecentDocumentPaths.v1`). |
| 19 | LOW | Not re-verified | n/a | Scroll positions keyed by path; not rechecked. |
| 20 | MEDIUM | Open | Low | Plist is still read with `NSDictionary(contentsOf:) as? [String: Any]` (`SharedPreferenceStore.swift:63, 258`); safe casts limit the effect. |
| 21 | POSITIVE | Removed | n/a | `QuickLookProbeEvidence.swift` deleted. |
| 22 | MEDIUM | Removed | n/a | The `--editor-state` option no longer exists. |
| 23 | MEDIUM | Removed | n/a | The ShortcutProbe target is gone. |
| 24 | LOW | Open | Low | Paths still logged with `%{public}@` (`LocalSchemeHandler.swift:40`, `MarkdownWebView.swift:707`). The log subsystem is still `com.markdownquicklook.app` (7 places). |
| 25 | POSITIVE | Holds | n/a | Export filename still comes from `deletingPathExtension().lastPathComponent` (`MarkdownWebView.swift:428`). |
| 26 | HIGH | Fixed | n/a | CSP is `script-src 'self' boa-renderer:` with no `unsafe-eval` (`Renderer/index.html:7`). Mermaid renders under it (see `MermaidRenderingTests`). |
| 27 | HIGH | Fixed | n/a | markdown-it is gone. cmark runs in safe mode and `BoaRender` tests reject `javascript:`, `vbscript:` and `data:` links. |
| 28 | HIGH | Removed | n/a | The app's DOMPurify configuration no longer exists. The Mermaid bundle contains its own DOMPurify, used in `strict` mode. |
| 29 | HIGH | Fixed | n/a | CSP `img-src` allows only `'self'`, `boa-renderer:`, `local-md:`, `data:`, `blob:`. No `file:`, `http:` or `https:`. `file://` links are now refused natively as well; see N1. |
| 30 | MEDIUM | Open | Low | The renderer still posts raw `href` values to native (`main.js:530`), and native does not check the scheme. A `javascript:` or other non-path value is treated as a relative path that does not exist, so it ends in a failure notice. Reasoned from code, not tested. |
| 31 | MEDIUM | Fixed | n/a | The exported HTML head now carries `default-src 'none'; style-src 'unsafe-inline'; img-src data: file:; font-src data:` (`main.js:261`). |
| 32 | MEDIUM | Partly addressed | Low | Font faces are excluded from the export (`collectStylesheetRules(false)`), and `@import` or `url()` targets are blocked by the export CSP. `img-src` still allows `file:`. |
| 33 | MEDIUM | Open | Low | `new RegExp(query, flags)` with a user-typed pattern (`search.js:219-221`). Only the user typing the pattern can trigger it, so this is a self-inflicted slowdown, not an attack on content. |
| 34 | MEDIUM | Removed | n/a | No `<base>` handling remains. |
| 35 | MEDIUM | Removed | n/a | `diff-animator` is gone. |
| 36 | LOW | Removed | n/a | `preprocessMermaidNewlines` is gone; Mermaid source is passed as written. |
| 37 | LOW | Removed | n/a | Typst removed. |
| 38 | LOW | Open | Low | The renderer still maps relative image paths to `local-md://` URLs (`main.js:149-157`); the native allowlist in `LocalSchemeHandler` is the real control and is unchanged. |
| 39 | LOW | Open | Low | SVG images are still re-serialised with `XMLSerializer` without removing `<script>` or animation elements (`svg-image-layout.js:96`). They are only shown through `<img>` or data URLs. |
| 40 | LOW | Removed | n/a | `acceptance.html` is gone. |
| 41 | LOW | Open | Low | `localStorage` is still used for two help-overlay flags (`help-overlay.js:103-112, 237-238`). Not sensitive. |
| 42 | LOW | Open | Low | `window.onerror` still forwards the raw message to the native logger (`main.js:40-42`). |
| 43 | LOW | Open | Low | Line-number wrapping still rebuilds `innerHTML` from template strings (`main.js:100-106`). Input is escaped code from cmark or highlight.js output. |
| 44 | HIGH | Open | Medium | `scripts/install.sh` still writes and runs `/tmp/set_default_handler.swift` at a fixed path (lines 95, 121, 125). Needs a local attacker on the same machine. Use `mktemp -d`. |
| 45 | MEDIUM | Removed | n/a | `benchmark/ql-bench` deleted. |
| 46 | MEDIUM | Removed | n/a | The npm build script is gone. |
| 47 | MEDIUM | Open | Medium | `install.sh` still ad-hoc signs the app and clears quarantine with `xattr -cr` (lines 63, 69, 137). Intended for development installs; keep it documented. |
| 48 | LOW | Removed | n/a | The Quick Look display-order code is gone from `install.sh`. |
| 49 | LOW | Removed | n/a | `benchmark/js-bench` deleted. |
| 50 | LOW | Partly addressed | Low | `verify_truncation.sh` is gone. `scripts/generate_large_md.sh` still has no `set -e`. |
| 51 | INFO | Removed | n/a | The probe target is gone from `project.yml`. |
| 52 | CRITICAL | Partly addressed | Medium | Same root cause as 1. The app is now sandboxed, so a renderer or parser bug can reach only the files you opened and the folders you allowed. What remains: the app holds `network.client` (required by `WKWebView`), so the sandbox does not block the network. Mitigations are that the app has no network code and the renderer's CSP (`default-src 'none'`, `connect-src 'none'`) blocks page requests. |
| 53 | MEDIUM | Partly addressed | Low | The `file:` base path is gone. SVG images load through `local-md://` or data URLs only. Re-serialisation is still unstripped (39). |
| 54 | MEDIUM | Partly addressed | Low | The export now has a CSP (31) but is not re-sanitised, and diagram SVG is serialised as is (Mermaid sanitises its own output in `strict` mode). The Mermaid zoom controls are removed from exports because they carry the `diagram-tools` class. |

### New findings since the original review

| # | Severity | Finding | Evidence | Suggested fix |
|---|----------|---------|----------|---------------|
| N1 | Medium, **Fixed** | **Clicking a local link could launch any file or application.** Relative and absolute paths and `file://` URLs resolved without restriction, and anything that was not a document type went to `NSWorkspace.shared.open`. Files created locally, for example by `git clone`, carry no quarantine flag. A click was required. **Fix:** links now resolve only inside the document's own folder tree. Absolute paths, `file:` URLs, any `..` component and null bytes are refused, and a symlink that leaves the tree is refused after resolution. Ordinary files ask before opening. Folders, application and other bundles, scripts, installers and any file with the executable bit are only revealed in Finder. The navigation delegate no longer opens `file:` URLs. Covered by tests in `LinkNavigationTests` and `LocalLinkTargetTests`. | `LinkNavigation.swift` (`resolveLocalURL`, `isInsideDocumentTree`, `action(for:)`, `mightRunCodeOrIsFolder`); `MarkdownWebView.swift` (`handleLinkClick`, `decidePolicyFor`) | None. Side effect: links such as `../README.md` from a subfolder no longer work. |
| N2 | Medium | **Hardened runtime is off in Release** (`ENABLE_HARDENED_RUNTIME = NO`), so the app cannot be notarised as built. | `xcodebuild -showBuildSettings` | Enable it, drop `allow-jit` (finding 3), and run the tests and a manual check. |
| N3 | Info | **Mermaid 12.3.0 is vendored** (on branch `feat/mermaid-diagrams`, not yet merged) as a 5.5 MB minified bundle that inlines other libraries (DOMPurify 3.4.17, the ELK layout engine, KaTeX, lodash and others). It runs with `securityLevel: 'strict'` under the strict CSP, contains no `eval`, `new Function` or network APIs (searched), and is the latest release. It has not been audited independently. | `Renderer/vendor/mermaid/VENDORED.md` | Track upstream advisories; re-run the checks in `VENDORED.md` on every upgrade. |
| N4 | Low | **README overstates remote content.** It says a document can still make the web view load a remote image. The CSP `img-src` suggests those loads are blocked. Not tested. | `README.md`; `Renderer/index.html:7` | Test with a remote image, then correct whichever is wrong. |
| N5 | Info | **Thread safety in `LocalSchemeHandler`.** The `allowedFileURLs` setter changes `resourceGeneration` and `loadedBytes` before taking the lock that guards `allowedFilePaths`. Safe only if always called on the main thread. | `LocalSchemeHandler.swift:20-26` | Put all mutable state under one lock or mark the class `@MainActor`. |
| N6 | Low | **Other URL schemes are treated as relative paths.** `mailto:` and similar links end in a "could not open" notice instead of being handled deliberately. | `MarkdownWebView.swift:973-995` | Open `mailto:` and ignore or reject the rest explicitly. |
| N7 | Low | **Exported HTML allows local images.** The export CSP includes `img-src data: file:`. | `main.js:261` | Drop `file:` once all local images are inlined as data URLs. |

### Current remediation order

| Priority | Items | Effort |
|----------|-------|--------|
| Done | N1 (local links confined to the document's folder tree; ask before opening; reveal risky items only) | Small |
| Done | 1 and 52 (App Sandbox enabled; see `docs/sandbox-plan.md`) | Large |
| P2 | 3 and N2 (hardened runtime, drop `allow-jit`) | Small |
| P2 | 13 and 8 (restrict the `markdownpreview://` path; default-cancel navigation) | Small |
| P2 | 44 and 47 (installer temp file and signing notes) | Small |
| P3 | 11 and 30 (typed JS bridge, scheme check on `linkClicked`) | Medium |
| P3 | 9, 24, 17, 20, N5, N6 (message size caps, log redaction, typed plist, locking, scheme handling) | Small to medium |
| P3 | 33, 39, 41, 42, 43, 50, N4, N7 | Small |

---

## 1. Executive Summary (original review, written against the older code base)

BoaMarkdown is a macOS Markdown preview application consisting of a native Swift
app, a Finder Quick Look extension (sandboxed), a Swift XPC launcher service, and
a TypeScript web renderer that runs inside `WKWebView`. The project was forked
from `xykong/flux-markdown` with telemetry, auto-updates, and issue reporting
removed.

A total of **54 findings** were identified across three codebases:
**25 in the Swift application source**, **18 in the web renderer**, and
**10 in build/install/diagnostic scripts**. The most severe issues stem from
the **main application running entirely unsandboxed** (App Sandbox disabled),
which elevates every other finding (file system, network, IPC, code execution)
from theoretical to directly exploitable.

The renderer uses DOMPurify for HTML sanitization and implements
defense-in-depth for diagram/math output, but several CSP weaknesses,
diagram-engine risks, and path-resolution gaps remain.

| Severity | Count |
|----------|-------|
| Critical | 1 |
| High     | 7     |
| Medium   | 18    |
| Low      | 28    |
| Informational | 1 |
| **Total** | **54** (plus positive observations) |

---

## 2. Scope & Methodology

### Files reviewed

| Area | Files | Primary languages |
|------|-------|-------------------|
| Swift application sources | 48 `.swift` files in `Sources/{Markdown,MarkdownPreview,SearchLauncher,ShortcutProbe,Shared}/` | Swift |
| Entitlements & plists | 5 `.entitlements` + 4 `Info.plist` | XML |
| Web renderer | 35 `.ts` + `index.html`, `acceptance.html`, `vite.config.ts` | TypeScript/HTML/CSS |
| Build/install scripts | 33 `.sh`, `.py`, `.js`, `.cjs`, `.mjs`, `.swift` | Bash, Python, JS, Swift |
| Build config | `Package.swift`, `project.yml`, `Makefile`, `.version` | Swift, YAML, Make |

### Methodology

Three specialized subagents conducted deep reviews in parallel:
1. **Swift reviewer** — 48 source files, entitlements, plists, CLI modes,
   WebView configuration, IPC/XPC, URL scheme handling, deserialization.
2. **Web renderer reviewer** — 35 TypeScript modules + HTML/CSS build config.
   Focused on XSS, CSP bypass, injection, sanitization gaps, third-party
   library risks (Mermaid, Vega, Graphviz, Typst, KaTeX/MathJax).
3. **Scripts reviewer** — 47 script files across `scripts/` and `benchmark/`.
   Focused on command injection, path traversal, insecure temp files,
   privilege escalation, deserialization, hardcoded secrets.

Each subagent's findings were cross-referenced against the reviewer's own
reading of the same files.

---

## 3. Findings

Findings are grouped by area. Each entry includes a location, CWE (where
applicable), severity, evidence, and suggested fix. Positive security
observations follow the findings.

---

### 3.A. Application Entitlements & Sandboxing

#### FINDING 1 — CRITICAL: Main application has App Sandbox disabled

| Field | Detail |
|-------|--------|
| **Files** | `Sources/Markdown/Markdown.entitlements:5-10`, `Sources/Markdown/MarkdownRelease.entitlements` |
| **CWE** | CWE-250 (Excessive Privileges), CWE-1021 (Restrictions in Permissions) |
| **Severity** | **Critical** |

The `com.apple.security.app-sandbox` key is **commented out** in both the
debug and release entitlement files. The comment reads:

```xml
<!-- Temporarily disable App Sandbox for image loading -->
<!-- TODO: Re-enable sandbox with proper file access configuration -->
<!--
<key>com.apple.security.app-sandbox</key>
<true/>
-->
```

This means the main application process runs with **zero sandbox restrictions**:
it can read or write any file accessible to the user, make arbitrary outbound
network connections, spawn processes, and access Keychain items without
user prompting. Every file-system, network, and code-execution finding in this
report is amplified because the process is completely unrestricted.

**Suggested fix:** Re-enable App Sandbox with scoped bookmarks for
user-selected documents and `com.apple.security.files.user-selected.read-write`
entitlements. Configure the WKWebView URL scheme handler to load local images
through the sandboxed bookmark mechanism (already partially implemented in
`LocalSchemeHandler`).

---

#### FINDING 2 — HIGH: QuickLook extension requests read access to entire `$HOME`

| Field | Detail |
|-------|--------|
| **Files** | `Sources/MarkdownPreview/MarkdownPreview.entitlements:17-21`, `Sources/MarkdownPreview/MarkdownPreviewRelease.entitlements:17-21` |
| **CWE** | CWE-276 (Incorrect Default Permissions) |
| **Severity** | **High** |

The QuickLook extension is sandboxed (required by `pkd`), but it requests a
temporary exception granting read access to the entire home directory:

**Debug** — `$HOME/` (entire home directory):
```xml
<key>com.apple.security.temporary-exception.files.absolute-path.read-only</key>
<array>
    <string>$HOME/</string>
</array>
```

**Release** — `/` (entire filesystem under home, via home-relative path):
```xml
<key>com.apple.security.temporary-exception.files.home-relative-path.read-only</key>
<array>
    <string>/</string>
</array>
```

Since Quick Look can be triggered on any `.md` file in Finder (including
files shared by other users or downloaded from the internet), the sandbox
exception should be scoped to only the specific document directory and its
immediate image subdirectories, not the entire `$HOME`.

**Suggested fix:** Replace the broad `read-only` exception with
`com.apple.security.temporary-exception.files.bookmarks` scoped to the
specific document directory, resolved through `NSOpenPanel`/`UIDocumentPicker`
bookmarks or the `document-scoped bookmark` entitlement already present.

---

#### FINDING 3 — MEDIUM: `com.apple.security.cs.allow-jit` enabled on all targets

| Field | Detail |
|-------|--------|
| **Files** | All 5 entitlement files (main app debug + release, QL extension debug + release, SearchLauncher) |
| **CWE** | CWE-1021 (Restrictions in Permissions) |
| **Severity** | Medium |

`com.apple.security.cs.allow-jit` is present in all entitlement sets. While
Apple recommends JIT for `WKWebView` performance, it weakens the code-signing
boundary — JIT-compiled pages can allocate writable+executable memory, which is
a concern if the WebKit process is compromised (e.g., via a renderer exploit or
sanitization bypass).

**Suggested fix:** Evaluate whether JIT can be disabled. For a static
Markdown previewer, JIT is likely unnecessary — `allowsContentJavaScript` can
suffice without JIT. If retained, document the justification.

---

#### FINDING 4 — LOW: `get-task-allow` enabled in debug builds

| Field | Detail |
|-------|--------|
| **Files** | `Sources/Markdown/Markdown.entitlements:16-18`, `Sources/MarkdownPreview/MarkdownPreview.entitlements:23-25` |
| **Severity** | Low |

`com.apple.security.get-task-allow` is enabled in debug entitlements for both
the main app and the QL extension. This allows any process on the system to
attach a debugger to the app. Acceptable for development builds but should
never appear in release entitlements (it does not).

No action needed for release; debug-only is expected.

---

### 3.B. Swift Application Source Code

#### FINDING 5 — MEDIUM: Five CLI modes with minimal input validation

| Field | Detail |
|-------|--------|
| **File** | `Sources/Markdown/main.swift:4-59` |
| **CWE** | CWE-20 (Improper Input Validation), CWE-78 (OS Command Injection) |
| **Severity** | Medium |

The main entry point dispatches to five headless CLI modes based on
`CommandLine.arguments`:

- `--default-md-state` — dumps JSON to stdout
- `--repair-quicklook` — accepts `--editor-state <json>` argument parsed via
  `JSONSerialization.jsonObject` **before** `validEditorState()` validation
  (line 14). No size or depth limits on the JSON parse.
- `--quicklook-diagnostics` — prints diagnostic summary
- `--quicklook-self-test` — accepts `--probe-token <UUID>`, validated via
  `UUID(uuidString:)` (good)
- `--export-pdf <input.md> [output.pdf]` — exports to PDF

The `--editor-state` JSON is parsed with `JSONSerialization.jsonObject(with:)`
before any validation. While `JSONSerialization` does not execute code, a
maliciously crafted deeply-nested or very large JSON payload could cause
excessive memory/CPU consumption (DoS). The app runs unsandboxed, so the
process already has full privileges.

**Suggested fix:** Enforce a maximum byte length on the `--editor-state`
argument (e.g., 8192 bytes, consistent with `SearchLaunchPolicy.request`)
before parsing, and limit JSON nesting depth.

---

#### FINDING 6 — HIGH: `Process` spawned to open document in external editor

| Field | Detail |
|-------|--------|
| **File** | `Sources/Markdown/MarkdownWebView.swift:356-358` |
| **CWE** | CWE-78 (OS Command Injection) |
| **Severity** | **High** (elevated by no sandbox) |

When the user selects "Open in External Editor" (`Cmd+E`), the app spawns:

```swift
let task = Process()
task.launchPath = "/usr/bin/open"
task.arguments = ["-t", url.path]
```

The `url.path` is the path of the currently-opened document (controlled by
the user since they chose the file). However, since the app is **not
sandboxed**, the `/usr/bin/open` process inherits full file-system access.
If the document path contains shell metacharacters or special filenames,
`/usr/bin/open -t` could potentially be abused to open unintended files or
trigger unexpected Launch Services behavior. While `Process` arguments are
passed as an array (no shell interpolation), the `-t` flag resolves the
default text editor, which itself may not be trustworthy.

**Suggested fix:** Validate the URL path does not contain characters
suspicious for `open` (e.g., null bytes, which are already checked in
`DocumentOpenRequest`), and consider using `NSWorkspace.shared.open(_:withAppBundleIdentifier:)`
instead of shelling out.

---

#### FINDING 7 — HIGH: `Process` spawned with hardcoded system commands and full privileges

| Field | Detail |
|-------|--------|
| **File** | `Sources/Markdown/QuickLookRegistration.swift:76-90, 103-136` |
| **CWE** | CWE-78 (OS Command Injection), CWE-732 (Incorrect Permission Assignment) |
| **Severity** | **High** (elevated by no sandbox) |

The `QuickLookRegistration.run()` function spawns external processes with
hardcoded executables and arguments:

```swift
let commands: [(String, String, [String])] = [
    ("signature", "/usr/bin/codesign", ["--verify", "--deep", "--strict", appURL.path]),
    ("launchservices", ".../lsregister", ["-f", appURL.path]),
    ("extension-add", "/usr/bin/pluginkit", ["-a", extensionURL.path]),
    ("extension-enable", "/usr/bin/pluginkit", ["-e", "use", "-i", identifier])
]
```

And in `repair()`:
```swift
let command = runner("/usr/bin/defaults", args)  // writes plist values
let reset = runner("/usr/bin/qlmanage", ["-r"])
let reset = runner("/usr/bin/qlmanage", ["-r", "cache"])
```

These run `codesign`, `lsregister`, `pluginkit`, `defaults`, and `qlmanage`
with the full privileges of the (unsandboxed) app. The `appURL.path` and
`extensionURL.path` are derived from `Bundle.main.bundleURL`, which is
controlled by the app bundle location — not directly user-influenced. However,
since the app is not sandboxed, any compromise of the app (e.g., via a
renderer XSS exploit) grants the attacker the ability to run these commands
on arbitrary paths.

**Suggested fix:** Since these are repair/diagnostic functions (not called
on every launch), ensure they are only invoked through user-initiated actions
(menu items). Consider adding an explicit user confirmation dialog before
running repair operations.

---

#### FINDING 8 — MEDIUM: QuickLook extension navigation delegate allows arbitrary URL schemes

| Field | Detail |
|-------|--------|
| **File** | `Sources/MarkdownPreview/PreviewViewController.swift:1559-1608`, `Sources/Markdown/MarkdownWebView.swift:1020-1036` |
| **CWE** | CWE-94 (Improper Control of Generation of Code) |
| **Severity** | Medium |

Both the QL extension and main app implement `WKNavigationDelegate.decidePolicyFor navigationAction`. Both delegate methods handle `http`/`https` (open in browser) and `file://` (open externally) but the **else branch** falls through to `decisionHandler(.allow)`:

```swift
// PreviewViewController.swift:1606-1607
os_log("🔵 Allowing navigation (unhandled scheme: %{public}@)", ...)
decisionHandler(.allow)
```

```swift
// MarkdownWebView.swift:1033-1035
} else {
    decisionHandler(.allow)
}
```

This allows navigation to any URL scheme not explicitly handled — e.g.,
`javascript:` (though WKWebView generally blocks these in navigation),
custom schemes registered on the system, or `local-md://`/`flux-renderer:`
URLs that could be abused to load unexpected resources. While DOMPurify
sanitizes the markdown output and link clicks are intercepted by
`handleAnchorClick` in JavaScript, this is a defense-in-depth gap.

**Suggested fix:** Change the default to `decisionHandler(.cancel)` for any
unhandled URL scheme, and log a warning. Only allow navigation for the
explicitly trusted schemes (`local-md`, `flux-renderer`).

---

#### FINDING 9 — MEDIUM: WKWebView JavaScript enabled with message handlers and varying validation

| Field | Detail |
|-------|--------|
| **Files** | `Sources/Markdown/MarkdownWebView.swift:40-68`, `Sources/MarkdownPreview/PreviewViewController.swift:404-431` |
| **CWE** | CWE-94 (Improper Control of Generation of Code) |
| **Severity** | Medium |

Both WebView configurations enable JavaScript (`allowsContentJavaScript = true`)
and register four script message handlers: `logger`, `linkClicked`,
`readingToolsLayout`, and `blockCopy`. The `RendererBridgePolicy.accepts()`
check validates that messages originate from the **main frame** and the
correct URL scheme/host (`flux-renderer://bundle`). This is a good origin
check.

However, the `logger` handler accepts arbitrary string messages from the
renderer and logs them via `os_log`. The `linkClicked` handler receives
arbitrary `href` strings and passes them to `handleLinkClick()`. The
`blockCopy` handler receives `{id, generation, text}` objects and writes
them to the clipboard. While the origin check is solid, the **content** of
these messages is not validated for length or content before processing.
Since the renderer runs user-supplied content (markdown), a CSP bypass or
DOMPurify vulnerability could allow an attacker to send arbitrary data
through these channels.

**Suggested fix:** Enforce maximum message sizes on all message handlers.
For `linkClicked`, validate the href scheme before forwarding to native.
For `logger`, consider truncating excessively long messages.

---

#### FINDING 10 — MEDIUM: `<base href="file://">` injected into document head

| Field | Detail |
|-------|--------|
| **File** | `Sources/Markdown/MarkdownApp.swift` / `web-renderer/src/index.ts:928-940` (coordinated) |
| **CWE** | CWE-552 (Files Accessible to External Control) |
| **Severity** | Medium |

In `renderMarkdown()` (index.ts:937-939), a `<base>` tag is injected into
`document.head` with the document's directory as a `file://` URL:

```javascript
existingBase.setAttribute('href', `file://${baseHref}`);
```

This changes the base URL for **all** relative URLs in the document, including
those in user-rendered markdown content. If a malicious markdown file contains
a relative `<a href="config">` or `<img src="../secret.png">`, the resolved
URL becomes `file:///path/to/doc/dir/config` — potentially exposing local
files. While DOMPurify's `ALLOWED_URI_REGEXP` permits `file:` for `href`
attributes, and image loading is routed through the allowlisted
`local-md://` handler, the `<base>` tag affects non-sanitized contexts (e.g.,
`<a>` links that are handled by the native `handleLinkClick`, which resolves
relative paths against the file system).

**Suggested fix:** Consider setting the base href to the `flux-renderer:`
scheme instead of `file://`, or sanitize the `baseUrl` input server-side
before passing it to the renderer.

---

#### FINDING 11 — LOW: Swift string interpolation constructs JavaScript in `evaluateJavaScript`

| Field | Detail |
|-------|--------|
| **Files** | `Sources/Markdown/MarkdownWebView.swift:441,511,540`, `Sources/MarkdownPreview/PreviewViewController.swift:1094,1475`, `Sources/Shared/NativeMagnifyingWebView.swift:39` |
| **CWE** | CWE-94 (Improper Control of Generation of Code) |
| **Severity** | Low |

Several calls to `evaluateJavaScript` construct JavaScript via Swift string
interpolation with single-quote wrapping:

```swift
webView.evaluateJavaScript("window.setContentsSide('\(side.rawValue)');")
webView.evaluateJavaScript("window.updateTheme('\(theme)');")
webView.evaluateJavaScript("window.setRenderGeneration('\(documentGeneration)');")
```

These values come from internal enums (`ContentsSidebarSide`, appearance
theme) and UUID-based generation counters, so they are currently safe.
However, the pattern is fragile — if any interpolated value ever contained
a single quote, it would break out of the string context and enable
JavaScript injection. The native-to-JS bridge should use
`callAsyncJavaScript(_:arguments:in:in:)` with a dictionary-based argument
passing API instead.

**Suggested fix:** Replace string-interpolated `evaluateJavaScript` calls
with `callAsyncJavaScript` using the `arguments` parameter, which safely
serializes Swift values to JavaScript.

---

#### FINDING 12 — LOW: Web Inspector developer extras enabled in DEBUG builds

| Field | Detail |
|-------|--------|
| **File** | `Sources/Markdown/MarkdownWebView.swift:81-83` |
| **Severity** | Low |

```swift
#if DEBUG
webConfiguration.preferences.setValue(true, forKey: "developerExtrasEnabled")
#endif
```

This enables Web Inspector in debug builds, which is useful for development
but could allow an attacker who triggers a debug build to inspect and modify
the renderer's DOM. Release builds are not affected.

No action needed — DEBUG-only.

---

#### FINDING 13 — HIGH: `markdownpreview://` URL scheme accepts any absolute file path

| Field | Detail |
|-------|--------|
| **File** | `Sources/Shared/DocumentPosition.swift:31-37` |
| **CWE** | CWE-22 (Path Traversal), CWE-73 (External Control of File Name or Path) |
| **Severity** | **High** (elevated by no sandbox) |

The `markdownpreview://open?path=...` URL scheme handler validates that:

1. The scheme is `markdownpreview`
2. There is exactly one `path` query parameter
3. The path starts with `/` (absolute)
4. The path does not contain null bytes

But it accepts **any** absolute path — including `/etc/passwd`,
`/etc/shadow`, SSH keys, or any file on the system. Since the main app is
not sandboxed, `NSDocumentController.shared.openDocument(withContentsOf:...)`
will read and attempt to display any file the user has access to. A
malicious website could craft a link `markdownpreview://open?path=/etc/passwd`
that, when clicked by the user, opens the file in the app.

**Suggested fix:** This is partially mitigated by requiring `path.hasPrefix("/")`
(which prevents URL scheme tricks but not absolute path attacks). To
harden: validate the file extension against the document type whitelist
before opening, or require the path to be within user-selected directories
(bookmark-scoped).

---

#### FINDING 14 — MEDIUM: External links opened without user confirmation

| Field | Detail |
|-------|--------|
| **Files** | `Sources/Markdown/MarkdownWebView.swift:984`, `Sources/MarkdownPreview/PreviewViewController.swift:1593,1601,1643` |
| **CWE** | CWE-451 (User Experience) |
| **Severity** | Medium |

Clicking a link to an `http://` or `https://` URL, or a `file://` URL,
launches it directly via `NSWorkspace.shared.open(url)` with no confirmation
dialog. This is standard behavior for a previewer but means a malicious
markdown document containing deceptive links could trigger external
application launches. The Quick Look extension has additional risk:
since it runs in a host process (Finder), unexpected `NSWorkspace.open`
calls could be used for host interference.

**Suggested fix:** No change required by default, but consider an
opt-in "confirm before opening external links" preference in Settings.

---

#### FINDING 15 — MEDIUM: TSV content interpreted as potential Mermaid diagrams

| Field | Detail |
|-------|--------|
| **File** | `Sources/Markdown/MarkdownDocument.swift:13-37` |
| **Severity** | Medium |

The `MarkdownDocument.init(configuration:)` checks if the file is a TSV
and routes it through `PreviewFileReader.decode` → `renderTSVTable`.
However, `MarkdownImageDocument.swift` inlines SVG images from markdown
references, and the TSV reader itself is bounded (500 KiB limit). The
`PreviewFileReader.read()` function also special-cases `.mmd` files,
wrapping their content as Mermaid blocks:

```swift
if url.pathExtension.lowercased() == "mmd" {
    content = "```mermaid\n\(content)\n```"
}
```

This means a `.mmd` file's content is passed directly to the Mermaid
renderer. While Mermaid content is rendered in the sandboxed WebView and
its SVG output is sanitized, a malicious `.mmd` file could attempt to
exploit Mermaid parser vulnerabilities. This is low-risk but worth noting
as a data-source boundary concern.

**Suggested fix:** No immediate action needed — Mermaid runs in the
WebKit renderer process (not the main app), and its SVG output is
sanitized by `sanitizeDiagramHTML`.

---

#### FINDING 16 — POSITIVE: XPC service validates caller code signatures

| Field | Detail |
|-------|--------|
| **File** | `Sources/SearchLauncher/main.swift:11-68` |
| **Severity** | Positive observation |

The `SearchLauncher` XPC service implements strong caller validation:

```swift
func trustedPreview(_ connection: NSXPCConnection) -> Bool {
    guard connection.effectiveUserIdentifier == getuid(),
          connection.processIdentifier > 0 else { return false }
    var code: SecCode?
    let attributes = [kSecGuestAttributePid: NSNumber(value: connection.processIdentifier)]
    guard SecCodeCopyGuestWithAttributes(nil, attributes, ..., &code) == errSecSuccess,
          let code, SecCodeCheckValidity(code, .strict, nil) == errSecSuccess else { return false }
    // ... verifies code signing info and bundle identifier
    return SearchLaunchPolicy.acceptsPeer(
        sameUser: true, validSignature: true,
        identifier: dictionary[kSecCodeInfoIdentifier] as? String ?? "",
        expectedExecutable: executable == expected)
}
```

The service validates:
1. Same user ID as the host
2. Valid code signature (strict validation)
3. Bundle identifier is `io.github.boaworm.Markdown.QuickLook`
4. Executable path matches the expected QuickLook extension

This prevents a malicious process from connecting to the XPC service and
requesting document opens.

---

#### FINDING 17 — MEDIUM: `getpwuid(getuid())` bypasses sandbox container path redirection

| Field | Detail |
|-------|--------|
| **File** | `Sources/Shared/SharedPreferenceStore.swift:205-227` |
| **CWE** | CWE-22 (Path Traversal) |
| **Severity** | Medium |

The `SharedPreferenceStore` uses `getpwuid(getuid())` to resolve the real
home directory, explicitly bypassing the sandbox container redirection:

```swift
private static func realHomeDirectory() -> URL {
    if let pw = getpwuid(getuid()), let home = pw.pointee.pw_dir {
        return URL(fileURLWithPath: String(cString: home))
    }
    return FileManager.default.homeDirectoryForCurrentUser
}
```

This writes preferences to
`~/Library/Application Support/FluxMarkdown/shared-preferences.plist` —
a predictable path outside the app's container. This is by design (to
share settings between the sandboxed extension and the unsandboxed app),
but the predictable path means:
- Any process running as the user can read/write the preference store
- The preferences are not protected by file permissions
- A malicious local process could tamper with settings (e.g., disable
  security-relevant rendering options)

**Suggested fix:** Set file permissions to `0600` (owner-only read/write)
on the plist file. Consider using the Keychain or a more randomized file
name for the preferences store.

---

#### FINDING 18 — LOW: Recent document paths stored in plaintext UserDefaults

| Field | Detail |
|-------|--------|
| **File** | `Sources/Shared/RecentDocumentHistory.swift:31-39` |
| **Severity** | Low |

Up to 20 file paths are stored as plaintext strings in
`UserDefaults.standard` under the key `BoaRecentDocumentPaths.v1`. These
are accessible to any process with access to the user defaults domain
(since the app is not sandboxed). No sensitive data is stored, but the
file paths reveal document locations.

**Suggested fix:** No action needed — document paths are not sensitive.
If privacy is desired, migrate to `UserDefaults(suiteName:)` with an
App Group container once sandboxing is re-enabled.

---

#### FINDING 19 — LOW: Scroll positions stored keyed by full file path in UserDefaults

| Field | Detail |
|-------|--------|
| **File** | `Sources/Shared/AppearancePreference.swift:358-412` |
| **Severity** | Low |

Scroll positions and window frame sizes are stored in UserDefaults,
keyed by the document's full file path. This creates a mapping of file
paths to user interaction data (scroll position, window size). Since the
app is not sandboxed, this data is accessible to other processes. Not a
direct security issue but a privacy consideration.

**Suggested fix:** No action needed for current scope. Consider hashing
file paths as keys if privacy is a concern.

---

#### FINDING 20 — MEDIUM: Plist deserialization without per-value type validation

| Field | Detail |
|-------|--------|
| **File** | `Sources/Shared/SharedPreferenceStore.swift:70-76` |
| **CWE** | CWE-502 (Deserialization of Untrusted Data) |
| **Severity** | Medium |

The `SharedPreferenceStore` deserializes the plist file with:

```swift
if let dict = NSDictionary(contentsOf: fileURL) as? [String: Any] {
    self.cache = dict
}
```

There is no per-value type validation — the store trusts that values in
the plist are the correct types (String, Bool, Double, etc.). A malicious
process could write a crafted plist (the file is at a predictable path,
writable by any process as the user) that contains unexpected types. This
could cause runtime type cast failures or, in edge cases, type confusion
if values are used in unsafe casts.

However, the `_synchronizeUnsafe()` method (line 235) validates that
cache values are plist-serializable before writing, and the `string()`,
`bool()`, `double()` accessors use safe casts (`as?`). So the impact is
limited to potential `NSInvalidArgumentException` crashes (DoS) rather
than code execution.

**Suggested fix:** Add explicit type checking in the read accessors, or
migrate to a typed `Codable` struct deserialized via `PropertyListDecoder`.

---

#### FINDING 21 — LOW: QuickLook diagnostic parses command output with post-parse validation (positive)

| Field | Detail |
|-------|--------|
| **File** | `Sources/Shared/QuickLookProbeEvidence.swift:36-49` |
| **Severity** | Positive observation |

The `QuickLookProbeEvidence` module uses `JSONSerialization` to parse
the output of a `log show` command, but applies post-parse validation
checking path format and expected fields. This is an appropriate pattern
for parsing command output from a trusted system utility.

---

#### FINDING 22 — MEDIUM: `--editor-state` JSON parsed before validation with no limits

| Field | Detail |
|-------|--------|
| **File** | `Sources/Markdown/main.swift:13-14` |
| **CWE** | CWE-20 (Improper Input Validation), CWE-400 (Uncontrolled Resource Consumption) |
| **Severity** | Medium |

```swift
let data = CommandLine.arguments[index + 1].data(using: .utf8)
let state = try? JSONSerialization.jsonObject(with: data) as? [String: String]
```

The `--editor-state` argument is serialized via `JSONSerialization` **before**
`validEditorState()` is called. The JSON payload has no size or depth limits.
A maliciously crafted deeply-nested or very large JSON string passed via
command line could cause excessive memory allocation.

**Suggested fix:** Enforce a maximum argument length (e.g., 8192 bytes)
before parsing. `JSONSerialization.jsonObject(with:)` accepts
`JSONSerialization.ReadingOptions.mutableContainers` but does not expose a
depth limit — consider a custom limit via `JSONDecoder` + `Decodable` with
`maximumDepth` enforcement.

---

#### FINDING 23 — MEDIUM: ShortcutProbe uses Accessibility API to traverse Finder UI hierarchy

| Field | Detail |
|-------|--------|
| **File** | `Sources/ShortcutProbe/main.swift:19,77-113` |
| **CWE** | CWE-250 (Excessive Privileges), CWE-284 (Improper Access Control) |
| **Severity** | Medium |

The `ShortcutProbe` is a development-only diagnostic tool that uses
`AXIsProcessTrusted()` and `AXUIElement` APIs to traverse the Finder's
accessibility element hierarchy, checking for the Quick Look shortcut
button's accessibility identifier and code-signing validity.

The tool:
- Checks `AXIsProcessTrusted()` for accessibility permission
- Creates an AX element hierarchy from the Finder's focused window
- Uses `unsafeBitCast` to convert between `CFTypeRef` and `AXUIElement`
  (line 84) — this is an unsafe cast but is guarded by a `CFGetTypeID`
  check
- Calls `AXUIElementCopyAttributeValue` on all elements in the hierarchy

The tool is ad-hoc signed (`CODE_SIGN_IDENTITY: "-"` in project.yml:101)
and is not embedded in the app bundle (it's a separate `QuickLookShortcutProbe`
application). It requires explicit accessibility permission from the user.

**Suggested fix:** Document that this tool requires accessibility
permission and is for development diagnostics only. The `unsafeBitCast`
is acceptable here because it's guarded by the `CFGetTypeID` check, but
consider using `unsafeBitCast`'s checked alternative if available.

---

#### FINDING 24 — LOW: Full file paths logged in system logs

| Field | Detail |
|-------|--------|
| **Files** | `Sources/Markdown/MarkdownWebView.swift:838,916,945`, `Sources/MarkdownPreview/PreviewViewController.swift:1303`, `Sources/Shared/SharedPreferenceStore.swift:247` |
| **CWE** | CWE-532 (Insertion of Sensitive Information into Log File) |
| **Severity** | Low |

Multiple `os_log` calls log full file paths using `%{public}@`, which
makes them visible in the system log:

```swift
os_log("Exported PDF to: %{public}@", log: log, type: .default, destinationURL.path)
os_log("SharedPreferenceStore] Failed to write preferences to %@", fileURL.path)
```

File paths of opened documents are visible to any process with access
to the unified logging system. While `%{public}@` is used (which is
appropriate for non-sensitive data in Apple's logging framework),
the full path reveals directory structures and potentially sensitive
file names.

**Suggested fix:** Consider logging only the filename (`lastPathComponent`)
instead of the full path, or use `%{private}@` for paths.

---

#### FINDING 25 — POSITIVE: Export filename safely derived from document filename

| Field | Detail |
|-------|--------|
| **File** | `Sources/Markdown/MarkdownWebView.swift:432-435` |
| **Severity** | Positive observation |

The export filename is derived from `fileURL.deletingPathExtension().lastPathComponent`,
which is safely sanitized by Foundation — it extracts only the final
path component without any directory separators. This prevents path
traversal in the save panel's default filename.

---

### 3.C. Web Renderer (TypeScript / JavaScript)

#### FINDING 26 — HIGH: CSP permits `unsafe-eval` in `script-src`

| Field | Detail |
|-------|--------|
| **File** | `web-renderer/index.html:5` |
| **CWE** | CWE-1022 (Insecure Default), CWE-79 (XSS amplification) |
| **Severity** | **High** |

```html
<meta http-equiv="Content-Security-Policy"
    content="default-src 'none';
             script-src 'self' flux-renderer: 'unsafe-eval';
             ...">
```

`'unsafe-eval'` allows `eval()`, `new Function()`, `setTimeout(string)`,
and similar constructs. MathJax, KaTeX, and highlight.js may use these.
If any XSS vector bypasses DOMPurify (e.g., a library bug, a
sanitization edge case, or a future code change), `unsafe-eval` makes
arbitrary code execution trivial.

**Suggested fix:** Audit which libraries require `unsafe-eval` and
investigate alternatives (e.g., KaTeX works without it; MathJax v4
may not need it; highlight.js does not use eval). Use nonce-based or
hash-based CSP as a replacement.

---

#### FINDING 27 — HIGH: `validateLink` override unconditionally allows `data:` URLs

| Field | Detail |
|-------|--------|
| **File** | `web-renderer/src/index.ts:418-423` |
| **CWE** | CWE-20 (Improper Input Validation) |
| **Severity** | **High** |

```javascript
const originalValidateLink = instance.validateLink.bind(instance);
instance.validateLink = function(url: string): boolean {
    if (url.startsWith('data:') || url.startsWith('local-md://')) {
        return true;
    }
    return originalValidateLink(url);
};
```

This overrides markdown-it's built-in link validation to accept **all**
`data:` URLs. While DOMPurify's `ALLOWED_URI_REGEXP` in `documentPolicy`
blocks `data:` URLs in `href`/`src` attributes, the `validateLink`
override means markdown-it will emit `data:` URLs into its HTML output
before DOMPurify runs. This is an unnecessary widening of the attack
surface — if a DOMPurify bypass is ever found, `data:` URLs in `href`
attributes (e.g., `data:text/html,<script>alert(1)</script>`) could
enable script execution.

**Suggested fix:** Remove the `data:` allowance from `validateLink` and
only permit `local-md://`. The `data:` URL image inlining is handled
separately via the `imageData` option (native code generates the data
URLs after sanitization).

---

#### FINDING 28 — HIGH: `sanitizeDiagramHTML` permits `foreignObject` with HTML integration points

| Field | Detail |
|-------|--------|
| **File** | `web-renderer/src/safe-html.ts:76-91` |
| **CWE** | CWE-79 (XSS) |
| **Severity** | **High** |

```javascript
const fragment = DOMPurify.sanitize(html, {
    USE_PROFILES: { html: true, svg: true, svgFilters: true, mathMl: true },
    ADD_TAGS: ['foreignobject', 'use'],
    HTML_INTEGRATION_POINTS: { foreignobject: true, 'annotation-xml': true },
    ...
});
```

The `HTML_INTEGRATION_POINTS` option tells DOMPurify that content inside
`<foreignObject>` elements is HTML (not SVG). This is needed for Typst
diagrams that use `foreignObject` for text rendering. However, this
creates an XSS risk: if a diagram engine (Mermaid, Vega, Graphviz, or
Typst) outputs a `<foreignObject>` containing `<script>` tags or event
handlers, DOMPurify's HTML sanitizer should strip them — but the
`HTML_INTEGRATION_POINTS` flag changes how DOMPurify processes the
content boundary.

The Typst renderer explicitly removes `<style>` and `<foreignObject>`
elements from its output (typst-renderer.ts:81), and Mermaid/Vega/Graphviz
output is also sanitized. But the `HTML_INTEGRATION_POINTS` setting is
a broad permission that could be exploited if a third-party library
outputs unexpected content inside `foreignObject`.

**Suggested fix:** Audit each diagram engine's output handling individually.
Consider removing `foreignObject` from `ADD_TAGS` if Typst is disabled
or only used in the transpiled path (QuickLook). Ensure the Typst
native path always strips `foreignObject` before output reaches
`sanitizeDiagramHTML` (it does at line 81, but this is fragile).

---

#### FINDING 29 — HIGH: `file:` scheme permitted in renderer, CSP, and DOMPurify

| Field | Detail |
|-------|--------|
| **Files** | `web-renderer/index.html:5`, `web-renderer/src/index.ts:419`, `web-renderer/src/safe-html.ts:59` |
| **CWE** | CWE-22 (Path Traversal), CWE-200 (Information Exposure) |
| **Severity** | **High** |

The `file:` scheme is allowed in three places:

1. **CSP** (`index.html:5`): `img-src 'self' flux-renderer: local-md: file: data: blob: https: http:`
2. **markdown-it `validateLink`** (`index.ts:419`): `if (url.startsWith('local-md://')) return true;`
3. **DOMPurify `ALLOWED_URI_REGEXP`** (`safe-html.ts:59`): includes `file:` in the allowed schemes

This means a markdown file can reference local files via `<img src="file:///etc/passwd">`
or `<a href="file:///etc/shadow">`. While images loaded via `<img>` are subject
to the `LocalSchemeHandler` allowlist (which only permits images in the allowed
list), the `<a href>` links are handled by `handleAnchorClick` in JavaScript
which forwards the href to the native `linkClicked` handler, and the native
`handleLinkClick` opens `file://` URLs via `NSWorkspace.shared.open()`.

Additionally, the `<base href="file://...">` tag (see Finding 40) means
relative URLs in user content resolve to `file://` paths, potentially
loading local resources without explicit user interaction.

**Suggested fix:** Remove `file:` from the CSP `img-src`, DOMPurify
`ALLOWED_URI_REGEXP`, and markdown-it `validateLink`. Use only `local-md:`
for local image loading and `flux-renderer:` for renderer resources.
Restrict `href` attributes to `http:`, `https:`, `mailto:`, and `local-md:`.

---

#### FINDING 30 — MEDIUM: `handleAnchorClick` forwards raw `href` to native handler with no secondary validation

| Field | Detail |
|-------|--------|
| **File** | `web-renderer/src/index.ts:1446-1448` |
| **CWE** | CWE-20 (Improper Input Validation) |
| **Severity** | Medium |

```javascript
window.webkit.messageHandlers.linkClicked.postMessage(href);
```

The `handleAnchorClick` function (which intercepts all click events in
capture mode) forwards the raw `href` value to the native `linkClicked`
message handler. While the native side (`handleLinkClick` in
MarkdownWebView.swift:980) validates HTTP/HTTPS and local file extensions,
**any** non-HTTP/HTTPS href is resolved through `LinkNavigation.resolveLocalLink`
which allows path traversal via `..` components (see Finding 38).

The native side does validate the resulting path (must start with `/`,
no null bytes), but there's no validation of the URL **scheme** — a
malicious `javascript:` or `data:` URL that bypasses DOMPurify could
reach this handler.

**Suggested fix:** In the native `handleLinkClick`, validate that the
href is a plain path or anchor before processing. Reject any href that
contains a URL scheme (e.g., `javascript:`, `data:`).

---

#### FINDING 31 — MEDIUM: `exportHTML()` generates HTML document with no CSP meta tag

| Field | Detail |
|-------|--------|
| **File** | `web-renderer/src/index.ts:812-857` |
| **CWE** | CWE-79 (XSS) |
| **Severity** | Medium |

The `exportHTML()` function generates a standalone HTML document for
export, but the generated `<head>` contains no `<meta>` CSP tag and no
script/style restrictions. The exported HTML includes:

- All CSS rules extracted via `collectStylesheetRules()` (which may
  contain `@import` or `url()` rules from third-party stylesheets)
- The rendered content via `clone.innerHTML` (which was previously
  sanitized by DOMPurify, but may contain SVG with event handlers)

If the exported HTML is later opened in a browser, any XSS payloads that
were neutralized by DOMPurify's context-aware behavior (but not fully
stripped) could execute. Additionally, `@import` rules in the extracted
CSS could load external stylesheets.

**Suggested fix:** Add a restrictive CSP meta tag to the exported HTML
document:
```html
<meta http-equiv="Content-SecurityPolicy" content="default-src 'none'; style-src 'unsafe-inline'; img-src 'self' data:;">
```

---

#### FINDING 32 — MEDIUM: `collectStylesheetRules` includes all CSS verbatim in export

| Field | Detail |
|-------|--------|
| **File** | `web-renderer/src/index.ts:759-774` |
| **CWE** | CWE-612 (Information Exposure), CWE-426 (Cross-Domain) |
| **Severity** | Medium |

```javascript
function collectStylesheetRules(includeWebFonts = true): string {
    let css = '';
    for (const sheet of Array.from(document.styleSheets)) {
        try {
            if (sheet.cssRules) {
                for (const rule of Array.from(sheet.cssRules)) {
                    css += rule.cssText + '\n';
                }
            }
        } catch (_e) { }
    }
    return css;
}
```

This function collects **all** CSS rules from all stylesheets in the
document, including third-party library styles (KaTeX, Mermaid, highlight.js,
Vega). The `@import` and `url()` rules within these stylesheets are
included verbatim. When the exported HTML is opened in a browser:

- `@import url(...)` rules could load external stylesheets
- `url(...)` references to external fonts or images could make network requests

This is a privacy/information-leakage concern for exported HTML: opening
an export could trigger network requests to third-party CDNs, potentially
revealing the user's IP address and viewing behavior.

**Suggested fix:** Filter out `@import` rules and rewrite `url()` references
to point only to bundled resources (or inline them as data URLs).

---

#### FINDING 33 — MEDIUM: ReDoS risk in search regex

| Field | Detail |
|-------|--------|
| **File** | `web-renderer/src/search.ts:218-221` |
| **CWE** | CWE-1333 (Inefficient Regular Expression Complexity) |
| **Severity** | Medium |

```javascript
private buildRegex(query: string, options: SearchOptions): RegExp {
    if (options.useRegex) {
        const flags = options.caseSensitive ? 'g' : 'gi';
        return new RegExp(query, flags);
    }
    ...
}
```

When "use regular expression" mode is enabled, the user's query is passed
directly to `new RegExp()` with no length limit, complexity check, or
timeout. A crafted regex like `(a+)+$` could cause catastrophic
backtracking (ReDoS) on certain markdown content, hanging the WebView
process. While invalid regexes are caught (`SyntaxError`), the ReDoS
class of attack is not mitigated.

**Suggested fix:** Enforce a maximum query length (e.g., 500 characters)
and consider using a `start` flag or regex timeout (available in
Node.js, not browsers). For the browser environment, wrap regex
execution in a `Promise.race` with a timeout.

---

#### FINDING 34 — MEDIUM: `<base href="file://">` injected with unsanitized `baseUrl`

| Field | Detail |
|-------|--------|
| **File** | `web-renderer/src/index.ts:928-940` (coordinated with native code) |
| **CWE** | CWE-22 (Path Traversal), CWE-502 (Deserialization) |
| **Severity** | Medium |

```javascript
if (options.baseUrl) {
    let existingBase = document.querySelector('base');
    if (!existingBase) {
        existingBase = document.createElement('base');
        document.head.insertBefore(existingBase, document.head.firstChild);
    }
    const baseHref = options.baseUrl.endsWith('/') ? options.baseUrl : options.baseUrl + '/';
    existingBase.setAttribute('href', 'file://' + baseHref);
}
```

The `options.baseUrl` comes from the native `MarkdownWebView` coordinator
(index.ts:447): `options["baseUrl"] = url.deletingLastPathComponent().path`
— the directory of the opened markdown file. This is a filesystem path,
not user-controlled in the typical case. However:

1. The `<base>` tag is set to `file://` + the path, which means **all**
   relative URLs in the rendered content resolve against this `file://`
   origin.
2. DOMPurify's `ALLOWED_URI_REGEXP` permits `file:` scheme for `href`
   attributes, so relative links in sanitized HTML could resolve to
   arbitrary local files.
3. If the markdown file's path contains special characters (e.g., `..`),
   the base URL could be used for path traversal.

**Suggested fix:** Consider whether the `<base>` tag is necessary.
If it is, validate the `baseUrl` path does not contain `..` traversal
components before constructing the `file://` URL. Alternatively, use
a virtual base (e.g., `flux-renderer://`) to prevent local file resolution.

---

#### FINDING 35 — MEDIUM: `escapeHtml` in `diff-animator.ts` does not escape quotes

| Field | Detail |
|-------|--------|
| **File** | `web-renderer/src/diff-animator.ts:3-5` |
| **Severity** | Medium |

```javascript
function escapeHtml(s: string): string {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/ /'&gt;');
}
```

This `escapeHtml` function only escapes `&`, `<`, and `>` — it does **not**
escape `"` or `'`. In the current usage (inside `<span>` content, not
attribute values), this is safe. However, the same function name and
pattern is used in `index.ts:121` (the main `escapeHtml`), which **does**
escape quotes. This inconsistency creates a maintenance hazard — if
the `diff-animator.ts` version is ever used in an attribute context, it
would enable attribute injection.

**Suggested fix:** Add quote escaping to both `escapeHtml` functions
for consistency and defense-in-depth.

---

#### FINDING 36 — LOW: `preprocessMermaidNewlines` injects literal `<br/>` HTML tags

| Field | Detail |
|-------|--------|
| **File** | `web-renderer/src/index.ts:91-118` |
| **CWE** | CWE-79 (XSS amplification) |
| **Severity** | Low |

```javascript
result = result.replace(/"((?:[^"\\]|\\.)*)"/g, (_match, inner: string) => {
    return '"' + inner.replace(/\\n/g, '<br/>') + '"';
});
```

This function converts `\n` escapes inside Mermaid quoted strings to
literal `<br/>` HTML tags **before** the content is passed to
`mermaid.render()`. The Mermaid renderer then processes the result. While
`mermaid.render()` is expected to produce safe SVG output (which is
subsequently sanitized by `sanitizeDiagramHTML`), the injection of raw
HTML tags into user content before rendering creates a theoretical
injection point if Mermaid's parser mishandles the `<br/>` tag inside
quotes.

**Suggested fix:** Verify that `mermaid.render()` properly escapes
HTML inside quoted string labels. Consider using `\n` consistently
and letting Mermaid handle line breaks.

---

#### FINDING 37 — LOW: Typst WASM compiler is not sandboxed with restricted base URL

| Field | Detail |
|-------|--------|
| **File** | `web-renderer/src/typst-renderer.ts:46-60` |
| **CWE** | CWE-94 (Improper Control of Code Generation) |
| **Severity** | Low |

```javascript
$typst.setCompilerInitOptions({ getModule: () => compilerWasmUrl });
```

The Typst WASM compiler is initialized with `disableDefaultFontAssets()`
and preload fonts, but no `baseURL` restriction or filesystem sandbox.
Typst's compiler could potentially attempt to access resources via
`fetch()` or `import` statements. However, the WASM module runs in the
WebKit renderer process and is constrained by the page's CSP. The Typst
source code is user-controlled (from markdown ```` ```typst ```` fences).

**Suggested fix:** The Typst WASM module is bundled and should not
make network requests (its `getModule` only loads the local WASM file).
Verify that the compiled WASM does not contain `eval` or external
resource loading capabilities. Consider setting a restrictive CSP
`connect-src` that only allows `self` and `local-md:`.

---

#### FINDING 38 — LOW: `resolveImageSource` path traversal to `local-md://` scheme

| Field | Detail |
|-------|--------|
| **File** | `web-renderer/src/index.ts:549-565` |
| **CWE** | CWE-22 (Path Traversal) |
| **Severity** | Low |

```javascript
const baseHref = `file://${options.baseUrl.replace(/\/$/, '')}/`;
const fileURL = source.startsWith('file:') ? new URL(source) : new URL(source, baseHref);
return `local-md://${fileURL.pathname}${cacheBust}`;
```

Relative image paths in markdown are resolved against the `file://` base
URL and then converted to `local-md://` URLs. The `new URL()` resolution
handles `..` traversal, and the `LocalSchemeHandler` on the native side
checks the allowlist (`isExplicitlyAllowed`). However, the path traversal
to `local-md:///etc/passwd.png` is possible if the markdown contains
`![alt](../../etc/passwd.png)` — the `LocalSchemeHandler` would reject
it (not in the allowlist), but the URL construction itself doesn't
validate against traversal.

**Suggested fix:** The native `LocalSchemeHandler` already mitigates
this via the allowlist. No additional fix needed, but document the
defense-in-depth chain.

---

#### FINDING 39 — LOW: SVG re-serialization via `XMLSerializer` does not strip `<animate>`/`<set>` elements

| Field | Detail |
|-------|--------|
| **File** | `web-renderer/src/svg-image-layout.ts:96` |
| **Severity** | Low |

```javascript
return 'data:image/svg+xml;charset=utf-8,' +
    encodeURIComponent(new XMLSerializer().serializeToString(svg));
```

When an SVG image is inlined (converted from `local-md://` to a data URL),
the SVG is parsed by `DOMParser` and re-serialized by `XMLSerializer`.
However, the re-serialized SVG is not stripped of `<animate>`, `<set>`,
or `<script>` elements before being re-encapsulated as a data URL.

While SVG elements loaded via `<img src="data:image/svg+xml,...">` do
**not** execute scripts or animations (browsers treat SVG-in-img as an
opaque image), this behavior is not guaranteed by the HTML spec and
has changed across browser versions. A future WebKit change could
re-activate SVG scripts/animations in data-URL images.

**Suggested fix:** After parsing the SVG with `DOMParser`, strip
`<script>`, `<animate>`, `<set>`, `<animateMotion>`, and
`<animateTransform>` elements before re-serializing. This is
defense-in-depth.

---

#### FINDING 40 — LOW: `acceptance.html` has no CSP meta tag

| Field | Detail |
|-------|--------|
| **File** | `web-renderer/acceptance.html` |
| **Severity** | Low |

The acceptance test harness HTML file (`acceptance.html`) has no
Content-Security-Policy meta tag, unlike `index.html` which has a
comprehensive CSP. If this file is ever loaded in a context where
user content is rendered (e.g., for testing purposes), it would
have no XSS protections.

**Suggested fix:** Add the same CSP meta tag to `acceptance.html`.

---

#### FINDING 41 — LOW: User preferences stored in `localStorage`

| Field | Detail |
|-------|--------|
| **Files** | `web-renderer/src/help-overlay.ts:286-296,452-453` |
| **CWE** | CWE-312 (Cleartext Storage of Sensitive Information) |
| **Severity** | Low |

The help overlay stores user preferences (e.g., "don't show again"
preference) in `window.localStorage`. While no sensitive data is stored,
`localStorage` is accessible to any script running in the document origin
— including any script that might bypass DOMPurify. This creates a
persistence channel for injected scripts.

**Suggested fix:** Use `sessionStorage` instead (cleared on navigation)
or store preferences in a `data-*` attribute on the document element,
set by native code. For the current scope, the data is non-sensitive,
but this is a defense-in-depth concern.

---

#### FINDING 42 — LOW: `window.onerror` forwards raw error messages to native logger

| Field | Detail |
|-------|--------|
| **File** | `web-renderer/src/index.ts:146-148` |
| **CWE** | CWE-532 (Insertion of Sensitive Information into Log File) |
| **Severity** | Low |

```javascript
window.onerror = function(message, source, lineno, _colno, _error) {
    logToSwift(`JS Error: ${message} at ${source}:${lineno}`);
};
```

JavaScript errors (including their messages, which may contain user
content such as markdown text fragments or file paths) are forwarded to
the native Swift logger via `window.webkit.messageHandlers.logger`.
These messages appear in the system log. If a malicious markdown file
triggers an error whose message contains sensitive content, that content
could be logged.

**Suggested fix:** Do not log raw error messages from `window.onerror`.
Log only the error type and source location, or sanitize the message
to remove user content.

---

#### FINDING 43 — LOW: `addLineNumbersToCodeBlocks` uses `innerHTML` without re-sanitizing

| Field | Detail |
|-------|--------|
| **File** | `web-renderer/src/index.ts:624-632` |
| **Severity** | Low |

```javascript
const rawHtml = codeEl.innerHTML;
const html = rawHtml.endsWith('\n') ? rawHtml.slice(0, -1) : rawHtml;
const lines = html.split('\n');
const wrappedLines = lines.map((lineHtml, i) =>
    `<span class="code-line" data-line="${i + 1}">${lineHtml}</span>`
).join('\n');
codeEl.innerHTML = wrappedLines;
```

The `innerHTML` of a code block is read, split by newlines, and each
line is wrapped in a `<span>`. The line content is inserted as a
template literal into `innerHTML` without re-sanitizing. The code
block content was originally escaped by `instance.utils.escapeHtml(str)`
in the highlight.js integration (index.ts:413), so the HTML should
contain only escaped text and `<span>` elements from highlight.js.

However, the `data-line="${i + 1}"` attribute is inserted via template
literal, not via `setAttribute()`. The `${i + 1}` is always a number,
so this is safe. The `lineHtml` is the raw innerHTML, which was
previously sanitized. This is a low-risk finding but represents a
pattern that could become dangerous if the sanitization chain is
weakened.

**Suggested fix:** Use `textContent` and `setAttribute` instead of
template literals for inserting dynamic content into HTML, even when
the content is expected to be safe.

---

### 3.D. Installation & Build Scripts

#### FINDING 44 — HIGH: Predictable temp file enables symlink attack / arbitrary code execution

| Field | Detail |
|-------|--------|
| **File** | `scripts/install.sh:131,157,161` |
| **CWE** | CWE-377 (Predictable Temporary File) |
| **Severity** | **High** |

```bash
cat << 'EOF' > /tmp/set_default_handler.swift    # line 131 — fixed path
...
swift /tmp/set_default_handler.swift            # line 157 — executes the file
...
rm -f /tmp/set_default_handler.swift            # line 161
```

The script writes Swift source code to a **fixed, predictable path**
`/tmp/set_default_handler.swift` and then compiles and executes it
with `swift`. An attacker who can create files in `/tmp` (any local
user with shell access) can:

1. **Pre-create** `/tmp/set_default_handler.swift` as a symlink to any
   file writable by the installer (e.g., `~/Library/LaunchAgents/`
   payload, or even the app binary at
   `/Applications/FluxMarkdown.app/Contents/MacOS/FluxMarkdown`).
   The `>` redirect **truncates** the symlink target.
2. **Race the write** to inject malicious Swift code before the
   `swift` command executes it.

This is a local privilege escalation vector: any local user can
compromise the installation of FluxMarkdown, potentially achieving
code execution in the context of the installing user.

**Suggested fix:** Use `mktemp -d` to create a private temporary
directory (mode 0700) and write the Swift file inside it:

```bash
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT
cat << 'EOF' > "$TMPDIR/set_default_handler.swift"
...
swift "$TMPDIR/set_default_handler.swift"
```

---

#### FINDING 45 — MEDIUM: Predictable temp directory in benchmark script

| Field | Detail |
|-------|--------|
| **File** | `benchmark/ql-bench/ql-bench.sh:20,142,168` |
| **CWE** | CWE-377, CWE-59 (Link Following) |
| **Severity** | Medium |

```bash
cold_out="/tmp/ql-bench-$$"    # line 20 — PID-based, predictable
...
rm -f "$cold_out"/*.png        # line 142 — follows symlinks
...
rm -rf "$cold_out"/*           # line 168 — follows symlinks
```

The temp directory name is `/tmp/ql-bench-$$` where `$$` is the shell's
PID. While PIDs are harder to guess than fixed names, they are still
predictable (an attacker can enumerate PIDs). The `rm -f` and `rm -rf`
commands follow symlinks, which could delete files in arbitrary
directories if an attacker pre-creates symlinks inside the temp directory.

**Suggested fix:** Use `mktemp -d` and `umask 077`. Also consider
using `rm -rf --one-file-system` to prevent cross-filesystem deletion.

---

#### FINDING 46 — MEDIUM: `npm ci` without `--ignore-scripts` in build script

| Field | Detail |
|-------|--------|
| **File** | `scripts/build-issue64-math-backend.sh:29` |
| **CWE** | CWE-1104 (Use of Unmaintained Dependency) |
| **Severity** | Medium |

The build script runs `npm ci` without `--ignore-scripts`, which
executes npm lifecycle scripts (`preinstall`, `postinstall`, etc.) from
the dependency tree. The script installs from a pinned legacy Git commit,
which may contain dependencies with malicious install hooks.

**Suggested fix:** Add `--ignore-scripts` to the `npm ci` command. If
post-install scripts are needed, run them explicitly with audited
commands.

---

#### FINDING 47 — MEDIUM: Ad-hoc re-signing and quarantine removal in install script

| Field | Detail |
|-------|--------|
| **Files** | `scripts/install.sh:75,77,83` |
| **CWE** | CWE-345 (Insufficient Verification of Data Authenticity) |
| **Severity** | Medium |

```bash
/usr/bin/codesign --force --sign - --entitlements "$TEMP_QUICKLOOK_ENTITLEMENTS" ...   # line 75/77
/usr/bin/xattr -cr "/Applications/FluxMarkdown.app"                                    # line 83
```

The install script re-signs the app with an **ad-hoc signature**
(`--sign -`) and **removes the quarantine attribute** (`xattr -cr`).
This disables Gatekeeper's runtime integrity verification for the
installed application. Any process can later modify the app bundle
without macOS detecting the tampering.

This is explicitly for **development/debug builds** (the `development`
install mode). Release installations distributed outside this script
should use a proper Apple Developer ID signature.

**Suggested fix:** Document clearly that development builds bypass
Gatekeeper. For release distributions, sign with a Developer ID
certificate and do not strip quarantine.

---

#### FINDING 48 — LOW: QuickLook extension display-order list reconstructed from system plist

| Field | Detail |
|-------|--------|
| **File** | `scripts/install.sh:102-107` |
| **Severity** | Low |

```bash
CURRENT_ORDER=$(defaults read com.apple.preferences.extensions.QuickLook displayOrder 2>/dev/null | tr -d '(),"' | tr -d ' \n' | xargs)
```

The install script reads and rewrites the system QuickLook extension
display order. The `tr` and `grep` operations process the plist output
without strict validation. While the values are filtered through a
regex (`^[A-Za-z0-9_.-]+$`), the `xargs` and `sed` pipeline could
be vulnerable to argument injection if a malicious extension identifier
contained unusual characters.

**Suggested fix:** Validate extension identifiers more strictly before
inserting them into the `defaults write` command.

---

#### FINDING 49 — LOW: Chromium launched with `--allow-file-access-from-files` and `--disable-web-security`

| Field | Detail |
|-------|--------|
| **File** | `benchmark/js-bench/bench.mjs:281` |
| **CWE** | CWE-250 (Excessive Privileges), CWE-942 (Permissive Network Policy) |
| **Severity** | Low |

```javascript
const browser = await chromium.launch({
    headless: true,
    args: ['--allow-file-access-from-files', '--disable-web-security'],
});
```

The benchmark script launches Chromium with security-critical flags
disabled: `--allow-file-access-from-files` (allows file:// URLs to
access other local files) and `--disable-web-security` (disables the
same-origin policy). While this is a **benchmark tool** (not the app
itself), these flags would be catastrophic if accidentally used in
production code.

**Suggested fix:** These flags are acceptable for a benchmark that
intentionally tests local rendering. Add a prominent comment
explaining why these flags are needed and that they must never be
used in production code.

---

#### FINDING 50 — LOW: Missing `set -e` and input validation in generator scripts

| Field | Detail |
|-------|--------|
| **Files** | `scripts/generate_large_md.sh:1-7`, `scripts/verify_truncation.sh:1-26` |
| **Severity** | Low |

`generate_large_md.sh` lacks `set -e`, meaning errors in file writing
are silently ignored:

```bash
#!/bin/bash
echo "# Large File Test" > large_test.md
for i in {1..100000}; do
  echo "This is line $i..." >> large_test.md
done
```

`verify_truncation.sh` kills the `qlmanage` process with `kill $QL_PID`
which violates the "never kill a process you didn't start" security
rule. Additionally, `kill` could target an unrelated process if the
PID is reused between the `&` launch and the `kill` call.

**Suggested fix:** Add `set -euo pipefail` to all shell scripts. In
`verify_truncation.sh`, track the `qlmanage` PID more carefully or use
`pkill -f` with a specific pattern (though this has its own risks).

---

#### FINDING 51 — INFORMATIONAL: ShortcutProbe uses ad-hoc code signing

| Field | Detail |
|-------|--------|
| **File** | `project.yml:101` |
| **Severity** | Informational |

```yaml
CODE_SIGN_IDENTITY: "-"
```

The `QuickLookShortcutProbe` target is ad-hoc signed (`CODE_SIGN_IDENTITY: "-"`).
This is appropriate for a development-only diagnostic tool, but the
target should be clearly documented as such and excluded from release
builds.

---

### 3.E. Cross-Cutting Concerns

#### FINDING 52 — CRITICAL: Defense-in-depth gap: non-sandboxed main app can exfiltrate via renderer

**The core architectural risk:** Because the main application is not
sandboxed (Finding 1), the entire defense-in-depth chain is weakened.
A successful XSS exploit in the web renderer (e.g., via a DOMPurify
bypass, a Mermaid/Vega/Typst parser bug, or the `file:` scheme
allowance) would allow arbitrary JavaScript execution in a process with
full file-system and network access. The renderer's CSP, DOMPurify
sanitization, and WKWebView navigation controls are the only barriers.

**Attack chain example:**
1. User opens a malicious `.md` file in Quick Look (presses Space)
2. The QL extension (sandboxed) renders the content in a WKWebView
3. A DOMPurify bypass allows `<img src="data:...">` or `<foreignObject>`
   to execute JavaScript (Finding 28)
4. The injected script calls `window.webkit.messageHandlers.linkClicked`
   (Finding 30 — no secondary validation)
5. The native handler opens the URL via `NSWorkspace.shared.open()`
   (Finding 14) — potentially loading remote content or opening
   local files

In the **main app** (not sandboxed), step 5 is significantly more
dangerous: the app can make network connections directly from JavaScript
(bypassing CSP `connect-src`) and read/write arbitrary files via the
non-sandboxed process.

**Suggested fix:** The single highest-impact fix is to **re-enable App
Sandbox** for the main application. This would constrain the blast radius
of any renderer vulnerability and align with the project's stated goal
of being "local-only."

---

#### FINDING 53 — MEDIUM: SVG image loading path not uniformly sanitized

| Field | Detail |
|-------|--------|
| **Files** | `web-renderer/src/svg-image-layout.ts:96`, `Sources/Markdown/MarkdownImageDataCollector.swift:48-52`, `Sources/Shared/LocalSchemeHandler.swift:106` |
| **CWE** | CWE-79, CWE-22 |
| **Severity** | Medium |

SVG images can be loaded via three paths:
1. **Inlined as data URLs** by `MarkdownImageDataCollector.collectImageData`
   (Swift) → processed by `svgImageMetrics`/`constrainSVGImage` (TS)
2. **Loaded via `local-md://` scheme** by `LocalSchemeHandler` (Swift)
   → served as `image/svg+xml`
3. **Loaded via `file://` base URL** (if DOMPurify allows `file:` href)

The SVG processing pipeline has inconsistent sanitization:
- `svg-image-layout.ts:readSVG()` blocks `<!DOCTYPE`/`<!ENTITY>` (XXE
  prevention) ✓
- `constrainSVGImage()` re-serializes via `XMLSerializer` but does NOT
  strip `<script>` or `<animate>` elements (Finding 39) ✗
- `LocalSchemeHandler` allows SVG but only via `<img>` (scripts don't
  execute in img context) ✓
- `MarkdownImageDataCollector` only inlines SVG images
  (`fileExtensions: ["svg"]`, line 552) ✓

The risk is low because SVG-in-`<img>` doesn't execute scripts, but the
inconsistent sanitization is a maintenance hazard.

**Suggested fix:** Add SVG element stripping to `constrainSVGImage()`
after re-serialization, as defense-in-depth.

---

#### FINDING 54 — MEDIUM: Exported HTML/PDF inherits raw content without post-export sanitization

| Field | Detail |
|-------|--------|
| **Files** | `Sources/Markdown/MarkdownWebView.swift:717-765` (exportHTML), `web-renderer/src/index.ts:783-857` (exportHTML in JS) |
| **CWE** | CWE-79 |
| **Severity** | Medium |

The HTML export pipeline:
1. `RendererExportPreparation.htmlScript` calls `window.prepareExport()`
   then `window.exportHTML()` (index.ts:812-857)
2. The JS `exportHTML()` clones the rendered DOM, removes UI controls,
   and serializes via `clone.innerHTML`
3. The native code (MarkdownWebView.swift:726-755) then converts
   `file://` and `local-md://` image `src` attributes to base64 data URLs

The exported HTML content was originally sanitized by DOMPurify, but:
- The export includes all CSS (including `@import` rules — Finding 32)
- No CSP meta tag is added (Finding 31)
- SVG elements (from images, diagrams) are serialized as-is without
  re-sanitization

If the exported HTML is shared or opened in a different context (e.g.,
viewed in a browser), any residual XSS vectors in the serialized content
could execute.

**Suggested fix:** Add a CSP meta tag to exported HTML, filter CSS
`@import`/`url()` rules, and re-run DOMPurify on the exported HTML
before writing to disk.

---

## 4. Positive Security Observations

Despite the issues above, the codebase demonstrates strong security
engineering in several areas:

### 4.1. Comprehensive DOMPurify sanitization

- **All rendered HTML** passes through `DOMPurify.sanitize()` with
  profile-specific configurations (`documentPolicy`,
  `sanitizeMathOutput`, `sanitizeDiagramHTML`).
- **Math output** (MathJax SVG) is sanitized twice — once by MathJax's
  HTML handler and once by `sanitizeMathOutput()` with a custom
  `FORBID_ATTR` list.
- **Diagram output** (Mermaid, Vega, Graphviz, Typst) is sanitized via
  `sanitizeDiagramHTML()`.
- **Math reference links** are validated against document IDs —
  references to non-existent or ambiguous IDs are stripped
  (math-engine.ts:102-119).

### 4.2. Strong XPC service caller validation

The `SearchLauncher` XPC service (`Sources/SearchLauncher/main.swift`)
implements robust caller authentication:
- ✅ Same user ID check (`connection.effectiveUserIdentifier == getuid()`)
- ✅ Valid code signature (`SecCodeCheckValidity` with strict validation)
- ✅ Bundle identifier verification (`io.github.boaworm.Markdown.QuickLook`)
- ✅ Executable path verification (matches expected extension path)

### 4.3. Robust URL scheme parsing

The `DocumentOpenRequest` URL scheme handler (`Sources/Shared/DocumentPosition.swift`)
implements:
- ✅ Scheme validation (`markdownpreview` only)
- ✅ Single path parameter enforcement
- ✅ Absolute path requirement (`hasPrefix("/")`)
- ✅ Null byte rejection
- ✅ Numeric line validation (digits only, 1-999999999)
- ✅ Fragment length limit (≤ 1024 characters)

### 4.4. Input size limits and resource bounding

- **Document size limit:** `BoundedFileReader.documentLimit = 32 MiB`
  (`Sources/Shared/BoundedFileReader.swift:5`)
- **QL preview limit:** 500 KiB truncation for Quick Look previews
- **Image budget:** 32 images, 8 MiB total, 8 MiB per-image
  (`MarkdownImageDataCollector.swift:10-17`)
- **Math limits:** 64 KiB per expression, 2 MiB total, 5000 items
  (`web-renderer/src/math-limits.ts:3`)
- **SVG size limit:** 12 MiB max for parsed SVGs
  (`svg-image-layout.ts:12`)
- **Block copy limit:** 4 MiB UTF-8 bound
  (`web-renderer/src/block-copy.ts:79`)
- **XPC request limit:** 8192 bytes for URL requests
  (`SearchLaunchProtocol.swift:12`)

### 4.5. Local resource allowlisting

The `LocalSchemeHandler` (`Sources/Shared/LocalSchemeHandler.swift`)
implements defense-in-depth:
- ✅ Only image extensions allowed (`.png`, `.jpg`, `.jpeg`, `.gif`,
  `.svg`, `.webp`)
- ✅ Explicit allowlist of file URLs (only images referenced in the
  markdown are loadable)
- ✅ Bounded file reading (`BoundedFileReader.read` with `maxBytes`)
- ✅ Aggregate resource budget tracking
- ✅ Security-scoped resource access (`startAccessingSecurityScopedResource`)
- ✅ Path containment check (`isContained`)

### 4.6. Safe inter-process data passing

- Content passed from Swift to the WebView is JSON-serialized via
  `JSONSerialization` before interpolation into JavaScript, preventing
  injection through markdown content.
- XPC messages use `NSXPCInterface` with a typed protocol, preventing
  arbitrary method invocation.
- The `SharedPreferenceStore` validates plist serializability before
  writing (`PropertyListSerialization.propertyList(_:isValidFor:)`).

### 4.7. XXE prevention in SVG parsing

The `readSVG()` function in `svg-image-layout.ts:20` explicitly blocks
`<!DOCTYPE` and `<!ENTITY` declarations, preventing XML External
Entity (XXE) attacks when parsing SVG data URLs.

### 4.8. Mermaid preprocessing

The `preprocessMermaidNewlines()` and
`preprocessMermaidGanttTaskColons()` functions (index.ts:34-118)
pre-process Mermaid source before passing it to `mermaid.render()`,
avoiding parser-specific edge cases that could lead to unexpected
behavior.

---

## 5. Prioritized Remediation Roadmap (original; see "Current status" for the live order)

| Priority | Finding(s) | Effort | Impact |
|----------|------------|--------|--------|
| **P0 — Immediate** | #1 (CRITICAL: re-enable sandbox), #44 (HIGH: temp file in install.sh) | High / Low | Eliminates root cause of all privilege findings |
| **P1 — Next release** | #13 (HIGH: URL scheme path traversal), #26 (HIGH: unsafe-eval CSP), #29 (HIGH: file: scheme) | Medium / Medium / Medium | Reduces XSS and file-access attack surface |
| **P2 — Near term** | #2 (QL ext home read), #3 (allow-jit), #14 (external links), #27 (data: URLs), #28 (foreignObject) | Low / Low / Low / Low | Defense-in-depth improvements |
| **P3 — Hardening** | #5, #6, #7, #8, #9, #10, #15, #17, #20, #22, #23, #30, #31, #32, #33, #34, #45, #46, #47, #52-54 | Various | Broader hardening |
| **P4 — Documentation** | #16, #4 (debug-only), #21, #24, #25, #49, #50, #51 | N/A | Positive findings and informational items |

---

## 6. Appendix: Complete Finding Index

| # | Severity | Area | Location |
|---|----------|------|----------|
| 1 | CRITICAL | Entitlements | `Sources/Markdown/Markdown.entitlements:5-10` |
| 2 | HIGH | Entitlements | `Sources/MarkdownPreview/MarkdownPreview*.entitlements:17-21` |
| 3 | MEDIUM | Entitlements | All 5 entitlement files (`cs.allow-jit`) |
| 4 | LOW | Entitlements | `Sources/Markdown/Markdown.entitlements:16-18` (debug `get-task-allow`) |
| 5 | MEDIUM | Swift/CLI | `Sources/Markdown/main.swift:4-59` |
| 6 | HIGH | Swift | `Sources/Markdown/MarkdownWebView.swift:356-358` |
| 7 | HIGH | Swift | `Sources/Markdown/QuickLookRegistration.swift:76-90,103-136` |
| 8 | MEDIUM | Swift | `Sources/Markdown/MarkdownWebView.swift:1020-1036` |
| 9 | MEDIUM | Swift/WebView | `Sources/Markdown/MarkdownWebView.swift:40-68` |
| 10 | MEDIUM | Swift/WebView | `Sources/Markdown/MarkdownApp.swift:206` + `index.ts:928-940` |
| 11 | LOW | Swift/JS injection | `MarkdownWebView.swift:441,511,540` + others |
| 12 | LOW | Swift/Debug | `Sources/Markdown/MarkdownWebView.swift:81-83` |
| 13 | HIGH | Swift/URL scheme | `Sources/Shared/DocumentPosition.swift:31-37` |
| 14 | MEDIUM | Swift | `Sources/Markdown/MarkdownWebView.swift:984` + others |
| 15 | MEDIUM | Swift/TSV | `Sources/Markdown/MarkdownDocument.swift:13-37` |
| 16 | POSITIVE | Swift/XPC | `Sources/SearchLauncher/main.swift:11-68` |
| 17 | MEDIUM | Swift/Files | `Sources/Shared/SharedPreferenceStore.swift:205-227` |
| 18 | LOW | Swift/Storage | `Sources/Shared/RecentDocumentHistory.swift:31-39` |
| 19 | LOW | Swift/Storage | `Sources/Shared/AppearancePreference.swift:358-412` |
| 20 | MEDIUM | Swift/Plist | `Sources/Shared/SharedPreferenceStore.swift:70-76` |
| 21 | POSITIVE | Swift/Debug | `Sources/Shared/QuickLookProbeEvidence.swift:36-49` |
| 22 | MEDIUM | Swift/CLI | `Sources/Markdown/main.swift:13-14` |
| 23 | MEDIUM | Swift/AX | `Sources/ShortcutProbe/main.swift:19,77-113` |
| 24 | LOW | Swift/Logging | `Sources/Markdown/MarkdownWebView.swift:838` + others |
| 25 | POSITIVE | Swift/Export | `Sources/Markdown/MarkdownWebView.swift:432-435` |
| 26 | HIGH | Web/CSP | `web-renderer/index.html:5` |
| 27 | HIGH | Web/Sanitization | `web-renderer/src/index.ts:418-423` |
| 28 | HIGH | Web/Sanitization | `web-renderer/src/safe-html.ts:76-79` |
| 29 | HIGH | Web/CSP | `web-renderer/index.html:5` + `safe-html.ts:59` |
| 30 | MEDIUM | Web/Link | `web-renderer/src/index.ts:1446-1448` |
| 31 | MEDIUM | Web/Export | `web-renderer/src/index.ts:812-857` |
| 32 | MEDIUM | Web/Export | `web-renderer/src/index.ts:759-774` |
| 33 | MEDIUM | Web/Search | `web-renderer/src/search.ts:218-221` |
| 34 | MEDIUM | Web/Base | `web-renderer/src/index.ts:928-940` |
| 35 | MEDIUM | Web/Escaping | `web-renderer/src/diff-animator.ts:3-5` |
| 36 | LOW | Web/Mermaid | `web-renderer/src/index.ts:91-118` |
| 37 | LOW | Web/Typst | `web-renderer/src/typst-renderer.ts:46-60` |
| 38 | LOW | Web/Images | `web-renderer/src/index.ts:549-565` |
| 39 | LOW | Web/SVG | `web-renderer/src/svg-image-layout.ts:96` |
| 40 | LOW | Web/CSP | `web-renderer/acceptance.html` |
| 41 | LOW | Web/Storage | `web-renderer/src/help-overlay.ts:286-296` |
| 42 | LOW | Web/Logging | `web-renderer/src/index.ts:146-148` |
| 43 | LOW | Web/HTML | `web-renderer/src/index.ts:624-632` |
| 44 | HIGH | Scripts | `scripts/install.sh:131,157,161` |
| 45 | MEDIUM | Scripts | `benchmark/ql-bench/ql-bench.sh:20,142,168` |
| 46 | MEDIUM | Scripts | `scripts/build-issue64-math-backend.sh:29` |
| 47 | MEDIUM | Scripts | `scripts/install.sh:75,77,83` |
| 48 | LOW | Scripts | `scripts/install.sh:102-107` |
| 49 | LOW | Scripts | `benchmark/js-bench/bench.mjs:281` |
| 50 | LOW | Scripts | `scripts/generate_large_md.sh`, `scripts/verify_truncation.sh` |
| 51 | INFO | Scripts | `project.yml:101` (ShortcutProbe ad-hoc signing) |
| 52 | CRITICAL | Architecture | Non-sandboxed app amplifies all renderer findings |
| 53 | MEDIUM | Web/SVG | `svg-image-layout.ts:96` + Swift SVG handling |
| 54 | MEDIUM | Web/Export | `Sources/Markdown/MarkdownWebView.swift:717-765` |

---

## 6. Methodology Note

This report was produced by three specialized subagents (Swift source,
web renderer, scripts) plus manual verification of key files by the
review coordinator. Each subagent read and analyzed every file in its
assigned scope against a structured checklist of security concerns
(CWE-based). Findings were then cross-referenced against the
coordinator's independent reading of critical files to ensure
accuracy.

The subagents' findings are reproduced above with file:line locations,
CWE classifications, evidence snippets, and suggested fixes. Where a
subagent finding was not fully captured (e.g., due to output truncation),
the coordinator's own reading of the file was used to reconstruct the
finding.

---

*Generated during a full security review of the boa-markdown codebase
(v1.50.828) on 2026-11-14.*
