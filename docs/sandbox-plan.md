# Sandboxing plan

Status: **the App Sandbox is enabled** in both `Markdown.entitlements` and
`MarkdownRelease.entitlements`. The sections from "State before the sandbox was enabled" down
are the original investigation and plan, kept as a record.

## Outcome

What was done, and what differed from the plan:

| Area | Result |
|------|--------|
| Entitlements | `app-sandbox`, `files.user-selected.read-write` (the save panel must write PDF and HTML exports), `files.bookmarks.app-scope`, `print` and `cs.allow-jit` (unchanged). |
| Network | **`network.client` is required.** Without it the `WKWebView` web content and GPU processes fail to launch ("Application does not have permission to communicate with network resources") and the page stays blank, although only bundled and local content is loaded. So the sandbox does not block the network. The app has no network code and the renderer's CSP blocks page requests. |
| Sibling images and linked files | `ScopedAccessStore` keeps security-scoped bookmarks. `FolderAccessPrompt` asks once per run for the document's folder when images next to it exist but cannot be read, then re-renders. Clicking a link to an unreadable sibling document prompts too. File ▸ Allow Access to Document Folder… asks again on demand. |
| Recents | `RecentDocumentHistory.record` stores a bookmark per file; "Open Recent" resumes access before opening. |
| Settings | `SharedPreferenceStore` uses the standard Application Support location, which the sandbox maps into the container. Nothing shares the file any more now that the Quick Look extension is gone. Settings saved by an unsandboxed build at the real-home path are not read. |
| External editor | Uses `NSWorkspace` instead of spawning `/usr/bin/open -t`. |
| `markdownpreview://open?path=` | Opens only paths the app can already reach; other paths are denied by the sandbox. |
| CLI `--export-pdf in out` | Not changed. It cannot reach arbitrary paths, so it works only for files the app can read and write. Consider removing it. |
| `allow-jit` | Left in place to change one thing at a time; probably unnecessary for `WKWebView`. |

Checked by hand: a document renders, the web view starts, and the renderer reports ready. Covered by
unit tests: the bookmark store, the folder-access check, and the entitlements. Still to check by hand:
Open Recent after a relaunch, exports, and a document with images beside it (the folder prompt).

## State before the sandbox was enabled (historical)

The Quick Look extension, its search launcher and their entitlements are gone, which
also removed the largest exposure this repo used to have: a whole-home temporary
exception (`/` home-relative plus `$HOME/` absolute) that let a nominally sandboxed
extension read `~/.ssh` and `~/Library`. Sandboxing is now a single-target problem.

| Target | Sandboxed | File access today | Blocker to sandboxing |
|---|---|---|---|
| `Markdown` (app) | No — `com.apple.security.app-sandbox` is commented out with a TODO in `Sources/Markdown/Markdown.entitlements:7`, and `Sources/Markdown/MarkdownRelease.entitlements` has no sandbox key at all | Process-wide read of anything the user can read | Sibling-image reads and the settings plist (below) |

Both entitlement files do carry `com.apple.security.files.user-selected.read-only`, so
the plumbing for a sandbox is in place; only the switch is missing.

## Two mechanisms that assume no sandbox

1. **Sibling image reads.** `Sources/Shared/LocalSchemeHandler.swift:55` calls
   `baseDir.startAccessingSecurityScopedResource()`, where `baseDir` is the document's
   directory (`Sources/Markdown/MarkdownWebView.swift:468`, assigned to the handler at
   `Sources/Markdown/MarkdownWebView.swift:474`). That call only succeeds for a URL that
   carries a sandbox extension. A document opened by path — from the Finder, from the
   recent-documents menu or through the `markdownpreview://` scheme — grants the *file*,
   never its parent directory, so the call returns false and the read falls back to
   whatever the entitlements allow, which today is everything. There is no bookmark
   machinery anywhere in `Sources/` — `grep -n bookmarkData Sources` is empty.
2. **Shared settings.** `Sources/Shared/SharedPreferenceStore.swift:25` persists to
   `~/Library/Application Support/BoaMarkdown/shared-preferences.plist`. A sandboxed
   process may not write outside its own container, and the App Group that used to carry
   this was dropped because macOS 26 rejects App Group containers for ad-hoc signed
   builds (noted in `Sources/Markdown/Markdown.entitlements:28`, upstream #13). So
   sandboxing needs either a user-granted folder bookmark or a container-only store.

## Staged plan, lowest risk first

1. **Measure before changing anything.** Switch the sandbox on in
   `Sources/Markdown/Markdown.entitlements` only — `MarkdownRelease.entitlements` stays
   as-is, so the daily build is untouched. Enable the subresource log
   (`defaults write io.github.boaworm.Markdown BOADiagnoseSubresources -bool true`) and
   read the denials, which arrive with the failing URL and the owning document:
   `log stream --predicate 'subsystem == "com.markdownquicklook.app"' --info --debug`
   Expected failures: sibling images, `~/Library/Application Support/...` writes.
2. **Per-folder bookmarks.** When a document opens, request its containing folder through
   `NSOpenPanel` the first time (one prompt per folder), store a security-scoped
   bookmark keyed by directory, and have `LocalSchemeHandler` resolve and
   `startAccessingSecurityScopedResource()` that bookmark instead of the bare directory.
   Then the Debug sandbox stays on, and sibling images work without a home-wide grant.
   `NSDocument` is not in play here — documents are opened directly — so nothing grants
   the directory for free.
3. **Settings storage.** A sandboxed app cannot keep writing to
   `~/Library/Application Support/BoaMarkdown/`. Either move the shared plist into a
   bookmark-backed folder picked once by the user, or accept a container-only store
   (`.sharedfilelist`/`UserDefaults` inside the container). Decide this before step 2
   lands, because it changes where bookmarks may be stored: a bookmark saved inside the
   container is unreadable after a container path change.
4. **Release.** Only once 2 and 3 hold in Debug, add `com.apple.security.app-sandbox` to
   `MarkdownRelease.entitlements`.

## Test matrix for any step that turns the sandbox on

- Document in `~/Documents` with `![](img/x.png)` sibling, absolute `file://` image, and
  an image reached through a symlinked directory.
- Document outside the granted roots (expect a logged denial, not a crash).
- Open by double-click, by **Open Recent**, by drag onto the window, and through
  `markdownpreview://open?path=…` with `&find=1`.
- `.tsv` view, PDF export (`Cmd+Shift+P`), HTML export (`Cmd+Shift+E`),
  `BoaMarkdown --export` CLI path (`Sources/Markdown/CLIExporter.swift`).
- Settings write and read after a relaunch, and after a rebuild with a different
  bundle-identifier suffix.
