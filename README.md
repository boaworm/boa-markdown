# boa-markdown

A stripped-down, local-only Markdown viewer for macOS: a small GUI app that opens `.md` files in a window.

This is a fork of [xykong/flux-markdown](https://github.com/xykong/flux-markdown). The upstream project is a full product with auto-updates, usage statistics, in-app issue reporting and a release pipeline. This fork keeps only the viewer, with everything that talks to the outside world removed. It is meant to be built from source and used on your own machine.

**Maintainer:** Henrik Thorburn ([@boaworm](https://github.com/boaworm))

## What was removed

| Removed | Notes |
|---------|-------|
| Auto-update | Sparkle, the appcast feed, update keys and the "Check for Updates" menu item |
| Telemetry | Usage statistics, promotion/source attribution, and the settings that controlled them |
| Nags | The GitHub star reminder and every "Star on GitHub" button |
| Issue reporting | In-app "Report an Issue", error reports, diagnostics bundles, settings-change history |
| Network code and file exceptions | All code that made network requests, and the `Telemetry/` file exceptions. The app is sandboxed and holds only the outgoing-network entitlement that `WKWebView` needs to start (see below) |
| Finder Quick Look | The preview extension you got by pressing `Space`, its Spotlight-search launcher helper, the `Space`-key registration, and the diagnostic scripts that surrounded them |
| Third-party Swift packages | Sparkle was the only one |
| Release machinery | DMG/Homebrew/MacPorts scripts, release and issue-triage workflows, release notes, changelog |
| Multi-language UI | The language picker, runtime localization switching, and the German, French, Spanish, Chinese and Arabic strings. The interface is English only |
| Upstream links and docs | Help-menu and Welcome-screen links to the upstream repo, the `docs/` tree, translated READMEs, upstream agent/process files |
| Outbound notifications | The Feishu workflows and scripts |
| npm renderer | The `web-renderer/` Vite project, its Node dependencies and the CI jobs that built it. Markdown is parsed in Swift by cmark-gfm |
| Diagram and chart engines | Mermaid, Vega, Vega-Lite, Graphviz and Typst lived in the npm renderer. Fenced `mermaid`, `vega`, `dot` and `typst` blocks now render as code, and `.mmd` files open as a ```mermaid code block |

When a failure happens, the app now shows a local message with a retry button (`Sources/Shared/FailureNotice.swift`). Nothing is sent to a second party.

## What is still here

- The two JavaScript libraries the renderer still needs: KaTeX for math and highlight.js for code colouring. Both are vendored under `Renderer/vendor/` with their licences and a checksum record, so nothing is fetched at build time.
- The app runs in the macOS App Sandbox. It can read the documents you open and the folders you allow, and write only where you save an export. Opening a document grants access to that file alone, so the first time you open one with images or links to siblings, BoaMarkdown asks you to allow its folder (File ▸ Allow Access to Document Folder… asks again). The choice is remembered.
- The sandbox does not block the network. `WKWebView` will not start in a sandboxed app without the outgoing-network entitlement, so the app holds it. What keeps the app local-only is that the code that made requests (updates, statistics, reporting) is gone, the renderer's Content-Security-Policy blocks page requests, including remote images, the web view refuses to navigate anywhere but the bundled renderer, and a content rule list blocks `http(s)`, `ws(s)` and `ftp` loads. Clicking an `http(s)` link still opens your browser.
- The command-line PDF export (`BoaMarkdown --export-pdf in.md out.pdf`) cannot reach arbitrary paths under the sandbox, so it only works for files the app can already read and write.
- Building needs no package manager: the Markdown parser is vendored C (`Vendor/cmark-gfm`), the renderer assets are in the repo, and `xcodegen` assembles the project.
- The app is named BoaMarkdown, with bundle identifiers under `io.github.boaworm`, and the upstream "flux" names (renderer scheme, JavaScript globals, CSS classes, environment variables) have been renamed to "boa". The `markdownpreview://` URL scheme is gone, so other apps cannot ask BoaMarkdown to open a path. Settings live in the app's container (`~/Library/Containers/io.github.boaworm.Markdown/Data/Library/Application Support/BoaMarkdown/`), so they do not carry over from an upstream FluxMarkdown install or from an earlier unsandboxed build.

The remaining code has not been fully audited yet. Changes from upstream are reviewed commit by commit before they are merged.

## Features

| Feature | Description |
|---------|-------------|
| Math | Inline and block expressions (KaTeX) |
| GFM | Tables, task lists, strikethrough, GitHub-style alerts |
| Code highlighting | Syntax highlighting for 40+ languages |
| Table of contents | Interactive panel with section tracking |
| YAML front matter | Rendered as a table |
| Export | PDF (`Cmd+Shift+P`) and HTML (`Cmd+Shift+E`) |
| Zoom and pan | `Cmd +/-/0`, `Cmd`+scroll, pinch |
| Local links | Relative links open files in the document's own folder or below it. Absolute paths, `file:` links and any `..` are refused. Other documents open in the app; ordinary files ask first; folders, apps, scripts, installers and executables are only shown in Finder, never opened |
| Position memory | Remembers scroll position per file |
| Themes | Light, Dark, or follow the system |
| Formats | `.md`, `.mdx`, `.rmd`, `.qmd`, `.mdoc`, `.mdc`, `.mmd`, `.livemd`, `.mkd`, `.mkdn`, `.mkdown`, `.mdwn`, `.mdown`, `.markdown`, plus read-only `.tsv` tables |

Settings (`Cmd+,`) cover appearance, rendering toggles (math, emoji, blockquote collapse), font size and code-highlighting theme.

### Keyboard shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd` + `+` / `-` / `0` | Zoom in / out / reset |
| `Cmd` + `F` | Find |
| `Cmd` + `Shift` + `E` | Export as HTML |
| `Cmd` + `Shift` + `P` | Export as PDF |
| `Cmd` + `,` | Settings |
| `?` or the **?** toolbar button | Shortcut and feature guide |

### TSV table previews

Open `.tsv` files in the app. UTF-8 (including BOM) and LF/CRLF/CR records are supported. Tabs separate columns; quotes, HTML, Markdown and formulas stay literal. The first record is data, with generated column numbers above it.

Previews show up to 500 KiB, 1,000 rows, 100 columns and 20,000 cells, and truncation is marked in the table, source view and exports. This is a read-only viewer, not a spreadsheet editor; quoted multiline fields and non-UTF-8 encodings are not supported.

## Build and install

Requirements: macOS 12 or later, Xcode, and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

The project is generated from `project.yml` using XcodeGen. Run `make` targets
to ensure the project file is regenerated before building:

```bash
git clone https://github.com/boaworm/boa-markdown.git
cd boa-markdown
make app            # regenerate (xcodegen) + build only (Release)
make install        # build + copy to /Applications
```

If XcodeGen is not installed or the project is already generated, a plain
`xcodebuild` can be used, but running through `make` is recommended so the
project file stays in sync with `project.yml`:

```bash
xcodegen generate     # regenerate BoaMarkdown.xcodeproj from project.yml
xcodebuild -project BoaMarkdown.xcodeproj -scheme Markdown -configuration Release build
```

Other targets:

```bash
make app CONFIGURATION=Debug     # debug build only
make install-debug               # debug build + install
make clean                       # clean build artifacts
```

## Troubleshooting

- **A broken image or renderer asset:** WebKit's own failure line is privacy-redacted (`Couldn't open <private>`).
  Enable subresource logging with `defaults write io.github.boaworm.Markdown BOADiagnoseSubresources -bool true`,
  then reopen the document and read the `Subresource failed:` lines in Console.app. Set the value back to `false` when done.
  `BOA_DIAGNOSE_SUBRESOURCES=1` does the same for one run when launching the executable from a terminal.

## License

GPL-3.0, inherited from upstream. See [`LICENSE`](LICENSE).

## Credits

Upstream: [xykong/flux-markdown](https://github.com/xykong/flux-markdown). The upstream project credits [markdown-preview-enhanced](https://github.com/shd101wyy/markdown-preview-enhanced) as an inspiration.
