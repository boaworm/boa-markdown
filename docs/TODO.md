# To do

- **Make `--export-pdf` work under the sandbox.** Paths given as arguments are denied, but file
  descriptors inherited from the shell stay usable, so `BoaMarkdown --export-pdf < in.md > out.pdf`
  is the likely shape. Images beside the document would still need a folder granted earlier.
- **Rework the test scripts and fixtures.** `scripts/test-recent-document-history.sh` compiles
  `RecentDocumentHistory.swift` on its own, which now needs `ScopedAccessStore` (not run; expected to
  fail). `Tests/fixtures` is mostly manual-check documents inherited from upstream: the Markdown
  ones are only read as a corpus by `testEveryRepositoryFixtureRendersWithoutActiveContent`, and
  `FileExtensionTests` mostly asserts that fixture files exist.
- **Bring `README.md` up to date on Mermaid.** It still says Mermaid was removed and that two
  JavaScript libraries remain.
