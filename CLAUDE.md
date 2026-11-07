# drake

A drag-and-drop source/target for macOS, modelled on
[mwh/dragon](https://github.com/mwh/dragon), with a history of past runs.
Swift 6 + SwiftUI, with AppKit underneath for the parts SwiftUI cannot do.
macOS 26, Xcode 26+.

## Building and testing

```sh
make               # Release build (only this Mac's architecture)
make install       # ~/.local/lib/Drake.app + ~/.local/bin/drake + man page
make test          # unit tests (Swift Testing), coverage off
make log           # last hour of drake's unified-log entries
drake --verbose …  # every log message mirrored to stderr
```

- Run `make` and `make test` once at the end of a change, not after each edit.
  Pipe their output through `grep -E 'error|warning'` or `tail`.
- **Zero warnings.** A build or test run that adds a warning is not done.
- Signing is ad hoc (`CODE_SIGN_IDENTITY = "-"`). Do not add a team or a
  certificate requirement.
- The shared scheme (`Drake.xcodeproj/xcshareddata/xcschemes/Drake.xcscheme`)
  keeps coverage off and tests only `DrakeTests`. Coverage instrumentation
  writes `default.profraw` into whatever directory the binary runs in, so it
  must never reach a Release build; `make install` refuses one that has it.
- Sources live in synchronized folders: adding or moving a `.swift` file
  under `Drake/` or `DrakeTests/` needs no project edit.

## Testing

**Do not write or run UI tests.** No XCUITest, no UI test target, no synthetic
key or mouse events.

When something needs checking in the interface (layout, a shortcut, a drag
landing, an animation, a menu), **install and open the app for the user**:

```sh
make install && cd <folder with files> && drake notes.txt data.csv
```

Then say what to look at and what changed. Never claim an interface behaviour
is verified when it has only been reasoned about. Screenshots are not available
here (no screen-recording permission).

Unit tests are expected for everything testable without the screen: option
parsing, item classification, path shortening, selection, window sizing
(`Metrics.contentSize`), sweep geometry, per-type icons, file info, history
persistence and grouping, model navigation and titles, the problem log. One
test file per subject in `DrakeTests/`.

## Project layout

| Folder | What lives there |
|---|---|
| `Drake/App/` | `main.swift`, `AppDelegate`, `DrakeWindow`, `WindowToolbar`, `MainMenu`, `TerminalKeys` |
| `Drake/Model/` | `Options`, `DrakeItem`, `FileInfo`, `Selection`, `PathFormatting`, `HistoryStore`, `HistorySection`, `AppModel` |
| `Drake/Views/` | `RootView`, `SourceView`, `TargetView`, `HistoryView`, `ItemRow`, `ItemIcon`, `Theme` |
| `Drake/AppKit/` | `DragSource`, `PasteboardWriters`, `DropTarget`, `DropTargetApp`, `MarqueeSelection`, `ContextMenu` |
| `Drake/Support/` | `Metrics`, `Log`, `Thumbnailer`, `FileTypeIcon` |
| `tools/` | `make-icon.swift` (draws the app icon), `check-shortcut.py` |

Model code has no SwiftUI import. Views hold no business logic beyond view
state; anything worth testing goes in the model or a pure helper.

## Code quality rules

- **No dead code.** No disabled feature flags, unused parameters, unused
  callbacks or "kept in case" helpers. Remove code that stops being called in
  the same change. Comments explain *why*, never history.
- **Swift 6 concurrency.** The app target defaults to `MainActor`. Pure value
  types and helpers (`Options`, `Selection`, `DrakeItem`, `FileInfo`,
  `Metrics`, `PathFormatting`, window-list maths) are `nonisolated` so tests and
  background work can use them. No `nonisolated(unsafe)` except the
  C-callback terminal state in `TerminalKeys`.
- **State** follows the SwiftUI checklist: `@State` is `private`; `@Observable`
  models are injected through `.environment`; bindings only where the child
  writes; `ForEach` over stable ids, never indices; `.animation` always with
  `value:`.
- **Each `View` is an invalidation boundary.** Extract subviews instead of
  growing `body`; pass a view only what it reads.
- **No disk access in `body`.** Views read file details through
  `FileInfoCache.shared.info(for:)`, which is dropped when the app becomes
  active. Act on files (drag, open, refuse a missing argument) with a fresh
  check (`DrakeItem.exists`).
- **Display scale** comes from `@Environment(\.displayScale)`, not `NSScreen`.
- **Modern API only.** Replace hard-deprecated APIs; prefer `Observations`
  over `withObservationTracking` loops, `URL(filePath:)`/`appending(path:)`,
  `ContentUnavailableView` for empty states. Liquid Glass only if the user asks
  (the system toolbar adopts it on its own).
- **Logging**, not `print`: `Log.app/.drag/.drop/.history/.thumbnails` with
  `.debug`, `.info`, `.warning`, `.error`. Warnings and errors also land in
  `~/Library/Logs/Drake/drake.log`. Every failure path that is swallowed (a
  `try?` that matters, a refused drop, a failed write) logs a warning or error.
  Standard output belongs to target mode's printed drops and nothing else.

## Interface conventions

- Always dark (`NSApp.appearance = .darkAqua`): near-black body, white text,
  one cool blue accent from the `AccentColor` asset (`Palette.accent`,
  `Palette.nsAccent`). Colours and fonts come from `Views/Theme.swift`; no
  literal colours or font sizes elsewhere unless one-off and commented.
- **No footer and no Close button.** The window title is the status line
  (`AppModel.windowTitle`: "3 Items", "2 of 3 Selected", "1 Received"); the
  compact toolbar (`WindowToolbar`) holds History, Back and the history search.
  Escape, `q` and ⌘W close.
- Plain `-` as a separator, never an em dash or a middle dot.
- Nothing redundant: a file in the working directory shows no location, and an
  unreadable size shows nothing rather than a bare separator.
- Everything starts selected, so a single drag sends the whole list.
- Every menu command lives in `MainMenu.swift`, is sent to the first responder
  (nil target) and lands on `AppDelegate`, which validates it. Focused text
  fields get Copy, Select All etc. first. Unmodified key equivalents (Delete)
  must be disabled while `DrakeWindow.isEditingText`.
- Accessibility: rows combine into one element with the selected trait; icon
  buttons carry labels; animations check `accessibilityReduceMotion`.

## Layout rules

`Drake/Support/Metrics.swift` is the single source of truth for geometry. The
views lay out from it and `Metrics.contentSize(mode:itemCount:options:width:)`
sizes the window from it, so they cannot drift. Change a row's height or
padding there.

- Window is 380pt wide, min 300, max 640. **Do not let it grow to fit paths**:
  shorten the path with `PathFormatting.abbreviate`.
- Height fits the rows exactly, up to `maxVisibleRows` (9), then scrolls. No
  minimum-height floor: one item means a window one row tall.
- Height refits only when the mode or item count changes, keeping the user's
  width; selection changes never resize.

## Why AppKit is used where it is

- `DragSource.swift` - SwiftUI's `.onDrag` carries one item with one
  representation. A real `NSDraggingSession` drags a whole selection and
  controls each item's pasteboard types. The same overlay view reports clicks,
  double-clicks, right-clicks and hover (tracking area) and shows the tooltip,
  because SwiftUI hover and help do not reach through it.
- `PasteboardWriters.swift` - a **file offers `public.file-url` alone**,
  matching Finder: sandboxed Mac Catalyst apps (WhatsApp) refuse a file drag
  that also advertises `public.utf8-plain-text`. Do not add text back to file
  items. A bare URI still offers URL + text.
- WhatsApp also refuses a file whose own type is text (`.md`, `.txt`, JSON,
  CSV, code), even from Finder. A drag starts with file URLs (so Terminal and
  editors get paths); while it is near a WhatsApp window (`DropTargetApp`, from
  the window list) the pasteboard is rewritten so text files become a
  `public.data` file promise (`DataFilePromise`), copied on drop.
- `MarqueeSelection.swift` - sits above the rows but reports itself unhit over
  a row, so pressing a row still drags while empty space sweeps.
- `DrakeWindow.swift` - Escape and `q` close via a local event monitor; SwiftUI
  shortcuts and responder overrides get swallowed by focus and the overlays.
  Both defer to a focused text field.
- `WindowToolbar.swift` / `MainMenu.swift` - the window is AppKit-built, so its
  toolbar and menu bar are too.
- `main.swift` - options are parsed and files checked before AppKit starts, so
  `--help`, `--version`, bad arguments and missing files behave like a CLI tool.

## Constraints

- Not sandboxed, and cannot be: it opens files named on the command line.
- Launched from a shell, not Finder, so the app sizes, centres and activates
  its own window (`activate(ignoringOtherApps:)` is deliberate: cooperative
  activation leaves the window behind the terminal).
- dragon's option set is the contract. Keep `-x -t -k -p -a -A -i -f -F -T -I -s
  -v`, `--help` and `--version` behaving as dragon documents them; additions get
  their own long options (`--history`, `--no-history`, `--no-animation`).

## Git

- Commit messages: a short imperative subject, a blank line, then what changed
  and why. **No `Co-Authored-By` or other attribution trailers.**
- Never commit `build/`, `*.profraw`, `xcuserdata/` or `.DS_Store`
  (`.gitignore` covers them). Check `git status` before committing.
