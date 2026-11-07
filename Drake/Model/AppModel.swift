//
//  AppModel.swift
//  Drake
//
//  Owns the window's mode, the item list, and the Finder-style selection.
//

import AppKit
import Observation

nonisolated enum AppModelError: LocalizedError {
    case missingFile(String)

    var errorDescription: String? {
        switch self {
        case .missingFile(let name): "The file `\(name)' does not exist."
        }
    }
}

@Observable
final class AppModel {
    nonisolated enum Mode: Equatable {
        /// Files given on the command line, or an entry opened from the history.
        case source
        /// Receives drops and prints them (`--target`).
        case target
        /// The list of past runs (`drake` with no files).
        case history
    }

    let options: Options
    let history: HistoryStore
    /// Directory the process was launched from; relative labels hang off it.
    let baseDirectory: URL

    var mode: Mode
    var items: [DrakeItem]
    var selection = Selection()
    /// Number of items received so far in target mode.
    var receivedCount = 0
    /// Title of the history entry currently loaded, if any.
    var openedEntryTitle: String?
    /// Text in the history search field.
    var historyQuery = ""

    /// History entry this run appends to, for target mode.
    private var currentEntryID: UUID?

    /// The screen the history browser was opened from, so it can be returned to.
    private var suspended: (mode: Mode, items: [DrakeItem], title: String?)?

    init(options: Options, history: HistoryStore) throws {
        self.options = options
        self.history = history
        let base = URL(filePath: FileManager.default.currentDirectoryPath, directoryHint: .isDirectory)
        self.baseDirectory = base

        let parsed = options.arguments.map { DrakeItem.fromArgument($0, relativeTo: base) }
        // dragon refuses to start when a named file is absent; so do we.
        for item in parsed where item.isFile && !item.exists {
            throw AppModelError.missingFile(item.raw)
        }
        self.items = parsed

        if options.startsInHistory {
            mode = .history
        } else if options.target {
            mode = .target
        } else {
            mode = .source
        }

        if options.recordHistory {
            switch mode {
            case .source:
                currentEntryID = history.record(items: parsed, directory: baseDirectory, kind: .source)
            case .target:
                currentEntryID = history.record(items: [], directory: baseDirectory, kind: .target)
            case .history:
                break
            }
        }

        if mode == .history, !parsed.isEmpty {
            suspended = (options.target ? .target : .source, parsed, nil)
        }

        // Opening with everything selected means one drag sends the lot.
        selection.selectAll(parsed.map(\.id))
    }

    // MARK: - Window chrome

    /// The window title doubles as the status line: what is listed, and how
    /// much of it a drag would carry when that is not everything.
    var windowTitle: String {
        switch mode {
        case .history:
            return "History"
        case .target:
            guard receivedCount > 0 else { return "Drop Target" }
            return "\(receivedCount) Received"
        case .source:
            if let openedEntryTitle { return openedEntryTitle }
            let total = items.count
            guard total > 0 else { return "Drake" }
            let noun = total == 1 ? "Item" : "Items"
            let selected = selection.count
            if options.dragAll || selected == 0 || selected == total {
                return "\(total) \(noun)"
            }
            return "\(selected) of \(total) Selected"
        }
    }

    var canGoBackToHistory: Bool {
        mode != .history && !history.entries.isEmpty
    }

    // MARK: - Selection

    var itemOrder: [UUID] { items.map(\.id) }

    /// Items a drag starting on `item` should carry: everything with `--all`,
    /// the whole selection when the item is part of a multiple selection,
    /// otherwise just the item.
    func dragPayload(startingAt item: DrakeItem) -> [DrakeItem] {
        if options.dragAll { return items.filter(\.exists) }
        if selection.count > 1, selection.contains(item.id) {
            return items.filter { selection.contains($0.id) && $0.exists }
        }
        return item.exists ? [item] : []
    }

    /// Selected items, or all of them when nothing is selected.
    var selectedItems: [DrakeItem] {
        selection.isEmpty ? items : items.filter { selection.contains($0.id) }
    }

    func click(on item: DrakeItem, modifiers: NSEvent.ModifierFlags) {
        selection.click(on: item.id, in: itemOrder, modifiers: modifiers)
    }

    func selectAll() {
        selection.selectAll(itemOrder)
    }

    func clearSelection() {
        selection.clear()
    }

    func moveSelection(by offset: Int, extending: Bool) {
        selection.move(by: offset, in: itemOrder, extending: extending)
    }

    // MARK: - Items

    func removeSelected() {
        guard !selection.isEmpty else { return }
        items.removeAll { selection.contains($0.id) }
        clearSelection()
    }

    func openSelected() {
        ItemActions.open(selectedItems)
    }

    func revealSelected() {
        ItemActions.reveal(selectedItems)
    }

    func copySelectedPaths() {
        ItemActions.copyPaths(selectedItems)
    }

    // MARK: - Navigation

    func open(entry: HistoryEntry) {
        Log.app.info("Opening history entry \"\(entry.summary)\" (\(entry.items.count) items)")
        items = entry.items
        openedEntryTitle = entry.summary
        selection.selectAll(itemOrder)
        // Navigating forward to a new screen; there is nothing to go back to.
        suspended = nil
        mode = .source
    }

    func showHistory() {
        if mode != .history {
            suspended = (mode, items, openedEntryTitle)
        }
        clearSelection()
        openedEntryTitle = nil
        mode = .history
    }

    /// True when the history browser was reached from a screen worth returning to.
    var canReturnFromHistory: Bool { mode == .history && suspended != nil }

    func returnFromHistory() {
        guard let suspended else { return }
        items = suspended.items
        openedEntryTitle = suspended.title
        mode = suspended.mode
        historyQuery = ""
        selection.selectAll(itemOrder)
        self.suspended = nil
    }

    // MARK: - Target mode

    /// Prints received items, keeps them when asked, and files them in history.
    func receive(_ received: [DrakeItem]) {
        guard !received.isEmpty else { return }
        Log.drop.info("Received \(received.count) item(s)")
        for item in received {
            emit(item.outputLine(printPath: options.printPath))
        }
        receivedCount += received.count

        if options.keep {
            let known = Set(items.map(\.uri))
            items.append(contentsOf: received.filter { !known.contains($0.uri) })
        }

        if options.recordHistory, let currentEntryID {
            history.append(items: received, to: currentEntryID)
        }

        if options.andExit {
            terminate()
        }
    }

    /// Plain text drops are printed but never become buttons, as in dragon.
    func receiveText(_ text: String) {
        guard !text.isEmpty else { return }
        Log.drop.info("Received \(text.count) characters of text")
        emit(text)
        if options.andExit { terminate() }
    }

    func dragEnded(accepted: Bool) {
        Log.drag.info("Drag ended; accepted: \(accepted)")
        if accepted && options.andExit {
            terminate()
        }
    }

    func terminate() {
        NSApp.terminate(nil)
    }

    // MARK: - Output

    /// Unbuffered so output is visible immediately when piped.
    private func emit(_ line: String) {
        FileHandle.standardOutput.write(Data((line + "\n").utf8))
    }
}

/// What the Open, Reveal and Copy commands do to a set of items, shared by the
/// source list and the history browser.
enum ItemActions {
    static func open(_ items: [DrakeItem]) {
        for item in items {
            guard let url = item.fileURL ?? URL(string: item.uri) else { continue }
            if !NSWorkspace.shared.open(url) {
                Log.app.warning("Could not open \(url)")
            }
        }
    }

    /// Selects the items in Finder, skipping any that no longer exist.
    static func reveal(_ items: [DrakeItem]) {
        let urls = items.filter(\.exists).compactMap(\.fileURL)
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    /// Paths for files, URIs otherwise, one per line.
    static func copyPaths(_ items: [DrakeItem]) {
        let text = items.map(\.dragText).joined(separator: "\n")
        guard !text.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
