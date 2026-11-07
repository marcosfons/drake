# drake

A drag-and-drop source and target for macOS, modelled on
[mwh/dragon](https://github.com/mwh/dragon) for X and Wayland, written in Swift
with native views, real file icons and a history of past runs.

Many applications — web apps, WhatsApp, Slack, browsers — expect files to be
dragged into them. If you do not habitually use Finder that is a problem:

```sh
drake file.tar.gz
```

opens a small window holding that file, ready to be dragged wherever you need it.

## Installing

```sh
make install                 # into ~/.local
make PREFIX=/usr/local install
make NAME=dd install         # different command name
```

This puts the app bundle in `$PREFIX/lib/Drake.app`, a launcher script at
`$PREFIX/bin/drake`, and the man page in `$PREFIX/share/man/man1`. The launcher
execs the app binary directly, so it inherits the working directory, arguments
and standard output like any other command-line tool.

If `~/.local/bin` is not on your `PATH`, add to `~/.zshrc`:

```sh
export PATH="$HOME/.local/bin:$PATH"
```

`make uninstall` removes all of it. `make test` runs the test suite.

Requires macOS 26 and Xcode 26. Not sandboxed — a tool that opens files named on
the command line cannot be.

## Using it

| | |
|---|---|
| `drake a.txt b.pdf` | a window holding those files, ready to drag out |
| `drake --target` | a window to drag files *into*; drops are printed to stdout |
| `drake --target --keep` | as above, but each drop stays as something draggable |
| `drake --and-exit f.txt` | quit as soon as one drag lands |
| `drake --all *.png` | one control that drags everything at once |
| `find . -name '*.log' \| drake --stdin` | take filenames from a pipe |
| `drake` | browse the history of previous runs |

Every dragon option is supported: `-x -t -k -p -a -A -i -f -F -T -I -s -v`,
`--help`, `--version`. See `man drake`, or `drake --help`.

A dragged file goes on the pasteboard as a **file URL** and nothing else, which
is exactly what Finder sends - so anything that takes a file from Finder takes it
from drake, including sandboxed Mac Catalyst apps such as WhatsApp. Those refuse
a file drag that also advertises plain text, which is why drake does not offer
it; the cost is that a target accepting dragged text but not dragged files gets
nothing, the same trade Finder makes. A dragged **URI** still goes on as a URL
and as plain text, since that is the only way to accept it.

### History

Runs that have files are recorded in
`~/Library/Application Support/Drake/history.json`. With no arguments, `drake`
shows them: each entry expands into the items it held, and you can drag any of
them straight out of the list, drag a whole entry at once, or reopen it as a
normal drag source. Entries can be searched, renamed, pinned and deleted.

`--no-history` skips recording a run. `-H` opens the history even when files are
given.

### Selection

Everything starts selected, so one drag sends the whole list.

| | |
|---|---|
| Click | select just that row |
| ⌘-click | toggle a row |
| ⇧-click | extend the range |
| Press and sweep in empty space | rubber-band select |
| ↑ / ↓, with ⇧ | move / extend |
| ⌘A ⌘O ⌘R ⌘C | select all, open, reveal in Finder, copy paths |
| ⌘Y / ⌘[ | show history / back to the files |
| Escape or `q` | close (`q` also works in the launching terminal) |

Dragging any selected row carries the whole selection.

## A global shortcut

macOS has no built-in way to bind a key to a command, but Shortcuts.app does it
in about a minute:

1. Open **Shortcuts.app** → **File ▸ New Shortcut**, name it `Drake`.
2. Add the **Run Shell Script** action with:
   ```sh
   $HOME/.local/bin/drake
   ```
3. In the shortcut's details pane (ⓘ), click **Add Keyboard Shortcut** and press
   **⌃⌥⌘D**.

I checked this machine before suggesting it: `⌥⌘D` is taken (Dock hiding) and so
is `⌃⌘D`, but `⌃⌥⌘D` is free. Verify any combo yourself with:

```sh
make check-shortcut KEY=ctrl+opt+cmd+D    # -> free, or the id that claims it
make check-shortcut                       # list everything in use
```

That reads macOS's own shortcut table, so it cannot see hotkeys registered
privately by launchers like Raycast or Alfred.

With no arguments that opens the history browser, which is usually what you want
from a hotkey: pick a previous run and drag it out again.

## Layout

The window is sized to its contents: 380pt wide, and exactly as tall as its rows
up to nine of them, after which the list scrolls. Long paths lose their middle
directories (`/Volumes/…/reports/summary.pdf`) rather than widening the window.

Icons come from Quick Look where the file has a real thumbnail, otherwise from a
per-type symbol (`.csv` a green table, `.mp3` a pink note, `.zip` a brown
zipper, …) classified by UTType, otherwise from Finder.

The window appears instantly. A 160ms scale-and-fade opening animation is
built in but off; set `isEnabled` to `true` in `Drake/OpenAnimation.swift` to
bring it back (`--no-animation` then skips it per run).

## Source

| | |
|---|---|
| `main.swift`, `Options.swift` | entry point and dragon-compatible option parsing |
| `AppModel.swift`, `Selection.swift` | modes, items, Finder-style selection |
| `DrakeItem.swift`, `PathFormatting.swift` | items and path shortening |
| `HistoryStore.swift` | the on-disk history |
| `DragSource.swift`, `DropTarget.swift` | the AppKit drag/drop bridges |
| `MarqueeSelection.swift` | rubber-band selection |
| `FileTypeIcon.swift`, `Thumbnailer.swift` | icons |
| `Metrics.swift` | window and row geometry, shared by views and window sizing |
| `SourceView`, `TargetView`, `HistoryView` | the three screens |

Licensed under the GNU GPL version 3, as dragon is.
