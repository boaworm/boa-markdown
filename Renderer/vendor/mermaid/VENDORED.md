# Vendored: Mermaid

- Source: https://cdn.jsdelivr.net/npm/mermaid@12.3.0/dist/mermaid.min.js (the npm package's prebuilt browser bundle, fetched directly; no npm or Node involved)
- Version: 12.3.0
- License: MIT, see `LICENSE` (fetched from the same package at the same version)

Copied unmodified:

| File | SHA-256 |
|------|---------|
| `mermaid.min.js` (minified IIFE, exposes `globalThis.mermaid`) | `336df803d87a38b70a01e736e666c8f7601d2ce42f5e47c8fafe5d721074b9a3` |

## What the bundle contains

`mermaid.min.js` inlines Mermaid's dependencies. Licenses found while reviewing the file:

| Component | Licence in the bundle | Used here under |
|-----------|-----------------------|-----------------|
| Mermaid | MIT | MIT |
| DOMPurify 3.4.17 | Apache-2.0 OR MPL-2.0 (stated in its `@license` comment) | Apache-2.0 |
| ELK layout engine (elkjs) | EPL-2.0 OR GPL-3.0-or-later (from the elkjs `package.json` on the registry, not stated in the bundle) | GPL-3.0-or-later |
| lodash | MIT (stated in the bundle) | MIT |
| jQuery-derived code, Bezier and Runge-Kutta helpers | MIT (stated in the bundle) | MIT |

Other inlined libraries (for example chevrotain, langium, KaTeX, d3, dagre, cytoscape, khroma) carry no licence text in the bundle.
They are believed to be MIT, Apache-2.0, ISC or BSD licensed, which GPL-3.0 accepts, but that has not been checked per package.

## Checks made on the file

- No `eval(`, `new Function(`, `XMLHttpRequest`, `WebSocket`, `sendBeacon` or `importScripts`.
- The 28 `fetch(` matches are all KaTeX's parser method `this.fetch()`, not network calls.
- The `http(s)://` strings are XML namespaces, documentation links and licence URLs.
- It runs under the renderer's CSP unchanged (`script-src 'self' boa-renderer:`, `connect-src 'none'`).

To upgrade: download the new `mermaid.min.js` and `LICENSE` for the pinned version, update the hash above,
repeat the checks above against the new file, and re-read its licence comments for changes.
