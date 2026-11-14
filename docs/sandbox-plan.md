# Sandboxing plan

Status: **investigation complete, no entitlement changed yet.** Every step below is
independently revertible; none of them is required to keep today's build working.

## Current state

| Target | Sandboxed | File access today | Blocker to sandboxing |
|---|---|---|---|
| `Markdown` (app) | No — `com.apple.security.app-sandbox` is commented out with a TODO in `Sources/Markdown/Markdown.entitlements:4` | Process-wide read of anything the user can read | Sibling-image reads and the settings plist (below) |
| `MarkdownPreview` (Quick Look) | Yes | Whole home directory, via a temporary exception: `/` home-relative in `Sources/MarkdownPreview/MarkdownPreviewRelease.entitlements`, `$HOME/` absolute in `Sources/MarkdownPreview/MarkdownPreview.entitlements` | Sibling-image reads |
| `SearchLauncher` (XPC) | Yes, user-selected read-only | n/a | none |
| `QuickLookShortcutProbe` | dev-only, not embedded | n/a | none |

Both exceptions mean a sandboxed extension can read `~/.ssh`, `~/Library`, everything.
That is the single largest exposure left in the fork, and it exists for one reason:
images referenced *relative to the document* (`![](img/diagram.png)`) live beside the
`.md` file, and Quick Look only grants the extension the previewed file itself.

## Two mechanisms that assume no sandbox

1. **Sibling image reads.** `Sources/Shared/LocalSchemeHandler.swift:55` calls
   `baseDir.startAccessingSecurityScopedResource()`, where `baseDir` is the document's
   directory (`Sources/Markdown/MarkdownWebView.swift:474`,
   `Sources/MarkdownPreview/PreviewViewController.swift:1409`). That call only succeeds
   for a URL that carries a sandbox extension. A Quick Look item, or a file opened
   through `NSDocument`, grants the *file*, never its parent directory, so the call
   returns false and the read falls back to whatever the entitlements allow. There is no
   bookmark machinery anywhere in `Sources/` — `grep -n bookmarkData Sources` is empty.
2. **Shared settings.** `Sources/Shared/SharedPreferenceStore.swift:29` persists to
   `~/Library/Application Support/BoaMarkdown/shared-preferences.plist`, read by the app
   and the extension. A sandboxed process may not write outside its own container, and
   the App Group that used to carry this was dropped because macOS 26 rejects App Group
   containers for ad-hoc signed builds (noted in both entitlements files, upstream #13).
   So sandboxing needs either a user-granted folder bookmark or a container both sides
   can reach.

## Staged plan, lowest risk first

1. **Measure before changing anything.** Build Debug with the sandbox switched on in
   `Sources/Markdown/Markdown.entitlements` only — `MarkdownRelease.entitlements` stays
   as-is, so the daily build is untouched. Enable the subresource log
   (`defaults write io.github.boaworm.Markdown BOADiagnoseSubresources -bool true`) and
   read the denials, which arrive with the failing URL and the owning document:
   `log stream --predicate 'subsystem == "com.markdownquicklook.app"' --info --debug`
   Expected failures: sibling images, `~/Library/Application Support/...` writes.
2. **Narrow the extension exception.** Replace `/` (and `$HOME/`) with an explicit list
   of home-relative roots that actually hold documents — typically `/Documents/`,
   `/Downloads/`, `/Pictures/`, `/Desktop/`. Drops `~/.ssh`, `~/Library` and dotfiles
   immediately, at the cost of documents that live elsewhere in home. This is a static
   entitlement, so it is a judgement call about your own layout, not a code change.
3. **Per-folder bookmarks for the app.** When a document opens, request its containing
   folder through `NSOpenPanel` the first time (one prompt per folder), store a
   security-scoped bookmark keyed by directory under
   `~/Library/Application Support/BoaMarkdown/`, and have `LocalSchemeHandler` resolve
   and `startAccessingSecurityScopedResource()` that bookmark instead of the bare
   directory. Then the Debug sandbox stays on, and sibling images work without a home
   wide grant.
4. **Settings storage.** Once the app is sandboxed, move the shared plist into a
   bookmark-backed folder picked once by the user, or accept a container-only split
   where the extension keeps its own copy of the render settings. Decide this before
   step 3 lands, because it changes where bookmarks must be stored.
5. **Extension.** Only after 3 and 4 have a proven bookmark pattern, try the same in the
   Quick Look extension and drop its temporary exception entirely.

## Test matrix for any step that turns the sandbox on

- Document in `~/Documents` with `![](img/x.png)` sibling, absolute `file://` image, and
  an image reached through a symlinked directory.
- Document outside the granted roots (expect a logged denial, not a crash).
- `.tsv` preview, PDF export (`Cmd+Shift+P`), HTML export (`Cmd+Shift+E`),
  `BoaMarkdown --export` CLI path (`Sources/Markdown/CLIExporter.swift`).
- Quick Look from Finder for the same documents, including one in `~/Downloads`.
- Settings write and read from both processes after a relaunch.
