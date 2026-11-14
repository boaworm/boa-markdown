# boa-markdown

A stripped-down, local-only Markdown viewer for macOS: a small GUI app plus a Finder Quick Look extension (press `Space` on a `.md` file).

This is a fork of [xykong/flux-markdown](https://github.com/xykong/flux-markdown). The upstream project is a full product with auto-updates, usage statistics, in-app issue reporting and a release pipeline. This fork keeps only the viewer, with everything that talks to the outside world removed. It is meant to be built from source and used on your own machine.

## What was removed

| Removed | Notes |
|---------|-------|
| Auto-update | Sparkle, the appcast feed, update keys and the "Check for Updates" menu item |
| Telemetry | Usage statistics, promotion/source attribution, and the settings that controlled them |
| Nags | The GitHub star reminder and every "Star on GitHub" button |
| Issue reporting | In-app "Report an Issue", error reports, diagnostics bundles, settings-change history |
| Network entitlements | `network.client` is gone from the Quick Look extension, the launcher and the app entitlements, as are the `Telemetry/` file exceptions |
| Third-party Swift packages | Sparkle was the only one |
| Release machinery | DMG/Homebrew/MacPorts scripts, release and issue-triage workflows, release notes, changelog |
| Multi-language UI | The language picker, runtime localization switching, and the German, French, Spanish, Chinese and Arabic strings. The interface is English only |
| Upstream links and docs | Help-menu and Welcome-screen links to the upstream repo, the `docs/` tree, translated READMEs, upstream agent/process files |
| Outbound notifications | The Feishu workflows and scripts |

When a failure happens, the app now shows a local message with a retry button (`Sources/Shared/FailureNotice.swift`). Nothing is recorded or sent.

## What is still here

- The renderer's JavaScript libraries (markdown-it, KaTeX/MathJax, Mermaid, Vega, Graphviz, Typst, highlight.js and so on). They are bundled into the app at build time and run locally. This fork does **not** remove them; trimming the ones you don't use is a possible next step.
- The macOS app itself is not sandboxed, so removing an entitlement does not technically block network access from it. What was removed is the code that made requests (updates, statistics, reporting). A document that references a remote image or a link can still cause the web view to load it, or open your browser when you click it.
- Building needs the network once, to fetch the renderer's npm packages.
- The app is named BoaMarkdown, with bundle identifiers under `io.github.boaworm`, and the upstream "flux" names (renderer scheme, JavaScript globals, CSS classes, environment variables) have been renamed to "boa". Only the `markdownpreview://` URL scheme is unchanged. Settings live in `~/Library/Application Support/BoaMarkdown/`, so they do not carry over from an upstream FluxMarkdown install.

The remaining code has not been fully audited yet. Changes from upstream are reviewed commit by commit before they are merged; see `.claude/skills/upstream-sync/SKILL.md` (local to the maintainer's checkout).

## Features

| Feature | Description |
|---------|-------------|
| Mermaid diagrams | Flowcharts, sequence diagrams, architecture diagrams |
| Math | Inline and block expressions (KaTeX / MathJax) |
| GFM | Tables, task lists, strikethrough, GitHub-style alerts |
| Code highlighting | Syntax highlighting for 40+ languages |
| Charts | Vega, Vega-Lite and Graphviz (DOT) |
| Table of contents | Interactive panel with section tracking |
| YAML front matter | Rendered as a table |
| Export | PDF (`Cmd+Shift+P`) and HTML (`Cmd+Shift+E`) |
| Zoom and pan | `Cmd +/-/0`, `Cmd`+scroll, pinch |
| Position memory | Remembers scroll position per file |
| Themes | Light, Dark, or follow the system |
| Formats | `.md`, `.mdx`, `.rmd`, `.qmd`, `.mdoc`, `.mdc`, `.mmd`, `.livemd`, `.mkd`, `.mkdn`, `.mkdown`, `.mdwn`, `.mdown`, `.markdown`, plus read-only `.tsv` tables |

Settings (`Cmd+,`) cover appearance, rendering toggles (Mermaid, KaTeX, Emoji), font size and code-highlighting theme.

### Keyboard shortcuts

| Shortcut | Action |
|----------|--------|
| `Space` | Quick Look preview (in Finder) |
| `Cmd` + `+` / `-` / `0` | Zoom in / out / reset |
| `Cmd` + `F` | Find |
| `Cmd` + `Shift` + `E` | Export as HTML |
| `Cmd` + `Shift` + `P` | Export as PDF |
| `Cmd` + `,` | Settings |

### TSV table previews

Open `.tsv` files in the app or preview them with Quick Look. UTF-8 (including BOM) and LF/CRLF/CR records are supported. Tabs separate columns; quotes, HTML, Markdown and formulas stay literal. The first record is data, with generated column numbers above it.

Previews show up to 500 KiB, 1,000 rows, 100 columns and 20,000 cells, and truncation is marked in the table, source view and exports. This is a read-only viewer, not a spreadsheet editor; quoted multiline fields and non-UTF-8 encodings are not supported.

## Build and install

Requirements: macOS 12 or later, Xcode, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`), and Node.js with npm.

The project is generated from `project.yml` using XcodeGen. Run `make` targets
to ensure the project file is regenerated before building:

```bash
git clone https://github.com/boaworm/boa-markdown.git
cd boa-markdown
make app            # regenerate (xcodegen) + build only (Release)
make install        # build + copy to /Applications and register Quick Look
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

Renderer tests (from `web-renderer/`): `npm ci && npm run typecheck && npm test`.

## Troubleshooting

- **Quick Look shows stale output:** `qlmanage -r`
- **Quick Look doesn't show up at all:** run **Help → Repair Quick Look…** in the app, or check `pluginkit -m -v` for the extension.
- **Check that Quick Look renders:** **Help → Test Quick Look**.

## License

GPL-3.0, inherited from upstream. See [`LICENSE`](LICENSE).

## Credits

Upstream: [xykong/flux-markdown](https://github.com/xykong/flux-markdown). The upstream project credits [markdown-preview-enhanced](https://github.com/shd101wyy/markdown-preview-enhanced) as an inspiration.
