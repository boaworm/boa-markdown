# Vendored: KaTeX

- Source: https://github.com/KaTeX/KaTeX/releases/tag/v0.19.1 (`katex.tar.gz`)
- Tag commit: `8000fbd4e29cca2c0cb1e88b745af3ed2f436b66`
- Archive SHA-256: `751e29ffb0c5bc184f08692a0aa905ff86a59ced07f635a27e72a7b7bc53036c`
- License: MIT, see `LICENSE` (copied from the repository at the tag)

Copied unmodified from the release archive:

| File | SHA-256 |
|------|---------|
| `katex.js` (readable, not minified) | `8f4f4efac9e80863b0ef9946c004928ad3bd33bbbeabcc8531c605c82a1bb545` |
| `katex.css` | `042b367bf8d89aef200f567f27aba119ec4204f9594e697609951e1295362ce8` |
| `contrib/mhchem.js` (chemistry, `\ce{}`) | `b193073c57b9ba833ca09faa72013c8995eb56fd2d27d65a6814c2e75f2370ab` |
| `fonts/*.woff2` (20 files) | see archive |

Left out: minified builds, ES-module builds, `.woff`/`.ttf` fonts, other contrib scripts.
`katex.css` still lists `.woff` and `.ttf` fallbacks; they are never requested once the `.woff2` loads.

To upgrade: download the new release archive, check its hash against the release page,
diff `katex.js` against this copy, scan the diff for network calls, dynamic code and URLs,
copy, and update the table above.
