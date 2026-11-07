# drake

A drag-and-drop source/target for macOS, modelled on
[mwh/dragon](https://github.com/mwh/dragon), with a history of past runs.
Swift + SwiftUI with AppKit underneath for the parts SwiftUI cannot do.

## Testing

**Do not write or run UI tests.** No XCUITest, no `-only-testing:DrakeUITests`,
no synthetic key or mouse events.

When something needs checking in the interface — a layout change, a keyboard
shortcut, a drag landing somewhere, an animation — **ask the user and open the
app for them to look at**:

```sh
cd <some folder with files> && drake notes.txt data.csv
```

Then say what to look at and what you changed. The user reports back. Never
claim an interface behaviour is verified when it has only been reasoned about;
say plainly that it needs a look.

Unit tests are welcome and expected for anything testable without the screen:
option parsing, item classification, path shortening, selection maths, sweep
geometry, per-type icons, history persistence, model navigation.

```sh
make test          # unit tests only
```

Screenshots are not available in this environment (no screen-recording
permission), which is another reason to hand interface checks to the user.

## Building and running

```sh
make               # build Release
make install       # ~/.local/lib/Drake.app + ~/.local/bin/drake + man page
make test
drake --verbose …  # logs mode and settled content size to stderr
```

`--verbose` reports the *computed* window size, not the live frame, because the
opening animation means the frame is still mid-flight when it logs.

## Layout rules

`Drake/Metrics.swift` is the single source of truth for window and row geometry.
Both the SwiftUI layout and `AppDelegate.contentSize(for:width:)` read it, so
they cannot drift. If a row's height or padding changes, change it there.

- Window is 380pt wide, min 300, max 640. **Do not let it grow to fit paths** —
  shorten the path instead, via `PathFormatting.abbreviate`.
- Height fits the rows exactly, up to `maxVisibleRows` (9), then scrolls. No
  minimum-height floor: one item means a window tall enough for one item.
- Height refits when the mode or item count changes, keeping the user's width.

## Interface conventions

- Plain `-` as a separator, never an em dash.
- Nothing redundant: a file in the working directory shows no location, and an
  unreadable size shows nothing rather than a bare separator.
- Everything starts selected, so a single drag sends the whole list.

## Why AppKit is used where it is

- `DragSource.swift` — SwiftUI's `.onDrag` carries one item with one
  representation. A real `NSDraggingSession` is needed to drag a whole selection
  and to control exactly which pasteboard types each item offers. A **file offers
  `public.file-url` alone**, matching Finder: sandboxed Mac Catalyst apps
  (WhatsApp) refuse a file drag that also advertises `public.utf8-plain-text`,
  rejecting it at drag-enter with no highlight at all. Do not add text back to
  file items. A bare URI still offers URL + text.
- WhatsApp also refuses a file whose *own* type is text (`.md`, `.txt`, JSON,
  CSV, code), even from Finder, because a file URL carries its type. A drag
  starts with file URLs (so Terminal and editors get paths); while it is near
  a WhatsApp window (`DropTargetApp`, from the window list) the pasteboard is
  rewritten so text files become a file promise of `public.data`
  (`DataFilePromise`), copied on drop.
- `MarqueeSelection.swift` — sits above the rows but overrides `hitTest` to
  report itself unhit over a row, so pressing a row still starts a drag while
  empty space sweeps.
- `DrakeWindow.swift` — Escape and `q` close the window, caught with a local
  event monitor. SwiftUI `.keyboardShortcut` and responder-chain overrides both
  get swallowed by SwiftUI focus and the drag/sweep overlays. Both keys defer to
  a focused text field, so `q` can still be typed into the history search.
- `main.swift` — options are parsed before AppKit starts so `--help`,
  `--version` and bad arguments behave like a normal CLI tool.

## Constraints

- Not sandboxed, and cannot be: it opens files named on the command line.
- Launched from a shell, not Finder, so the app sizes, centres and activates its
  own window.
- dragon's option set is the contract. Keep `-x -t -k -p -a -A -i -f -F -T -I -s
  -v`, `--help` and `--version` behaving as dragon documents them; additions get
  their own long options (`--history`, `--no-history`, `--no-animation`).
