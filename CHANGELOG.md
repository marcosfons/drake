# Changelog

All notable changes to drake. Versions follow [Semantic Versioning](https://semver.org);
`drake --version` prints the current one.

## [Unreleased]

### Added
- `make check`: Release build and unit tests, failing on any warning.

## [1.0.0] - 2026-11-07

First public release: drag and drop from the command line on macOS, a native
take on [mwh/dragon](https://github.com/mwh/dragon).

### Added
- Every dragon option: `-x -t -k -p -a -A -i -f -F -T -I -s -v`, `--help`,
  `--version`, plus `--history`, `--no-history` and `--no-animation`.
- History of past runs, grouped by date: drag single items or a whole run back
  out, reopen, search (⌘F), rename, pin and remove.
- Finder-style selection: click, ⌘-click, ⇧-click, rubber-band sweep, arrow
  keys. Everything starts selected, so one drag sends the whole list.
- Files are dragged as a file URL alone, like Finder, so sandboxed apps such
  as WhatsApp accept them; text files reach WhatsApp as attachments.
- Target mode: dropped files, URLs and text are printed to stdout.
- Dark native interface with a compact toolbar, full menu bar, Quick Look
  thumbnails and per-type icons.
- Unified logging (`make log`, `--verbose`) and a problem log in
  `~/Library/Logs/Drake`.

[Unreleased]: https://github.com/marcosfons/drake/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/marcosfons/drake/releases/tag/v1.0.0
