# Security and privacy

drake handles files you name and files dropped on it, so it should be clear
about what it touches.

## What drake does and does not do

- **Local.** Nothing leaves your Mac. drake makes no network requests.
- **Reads, does not change.** drake reads files only to show their icon,
  thumbnail and size and to put them on the drag pasteboard; ⌘O hands them to
  their default app. It never moves, renames or deletes them. Delete in its window removes a row from the
  list, not the file.
- **One copy, on purpose.** When a text file (`.md`, `.json`, code) is dragged
  into WhatsApp, drake copies it to the location WhatsApp gives it for the
  drop, because WhatsApp refuses text files offered by path.
- **Not sandboxed.** It opens whatever files you pass on the command line,
  with your user's permissions, like any command-line tool.
- **What it keeps.** `~/Library/Application Support/Drake/history.json` lists
  the files of past runs (`--no-history` skips it; the history's context menu
  removes a run). `~/Library/Logs/Drake/drake.log` keeps warnings and errors,
  which can name a file that failed. Delete either whenever you like.

## Reporting a vulnerability

Please use GitHub's private vulnerability reporting
(**Security > Report a vulnerability** on this repository) rather than a public
issue.
