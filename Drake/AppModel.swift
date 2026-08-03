//
//  AppModel.swift
//  Drake
//
//  Owns the window's mode, the item list, and the Finder-style selection.
//

import AppKit
import Foundation
import Observation

enum AppModelError: LocalizedError {
    case missingFile(String)

    var errorDescription: String? {
        switch self {
        case .missingFile(let name): return "The file `\(name)' does not exist."
        }
    }
}

@Observable
final class AppModel {
    enum Mode: Equatable {
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

    /// History entry this run appends to, for target mode.
    private var currentEntryID: UUID?

    /// The screen the history browser was opened from, so it can be returned to.
    private var suspended: (mode: Mode, items: [DrakeItem], title: String?)?

    init(options: Options, history: HistoryStore) throws {
        self.options = options
        self.history = history
        let base = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
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

    var windowTitle: String {
        switch mode {
        case .history: return "Drake - History"
        case .target: return "Drake - Target"
        case .source:
            if let openedEntryTitle { return "Drake - \(openedEntryTitle)" }
            return "Drake"
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
        for item in selectedItems {
            if let url = item.fileURL {
                NSWorkspace.shared.open(url)
            } else if let url = URL(string: item.uri) {
                NSWorkspace.shared.open(url)
            }
        }
    }

    func revealSelected() {
        let urls = selectedItems.compactMap(\.fileURL).filter { FileManager.default.fileExists(atPath: $0.path) }
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    func copySelectedPaths() {
        let text = selectedItems.map(\.dragText).joined(separator: "\n")
        guard !text.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    // MARK: - Navigation

    func open(entry: HistoryEntry) {
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
        selection.selectAll(itemOrder)
        self.suspended = nil
    }

    // MARK: - Target mode

    /// Prints received items, keeps them when asked, and files them in history.
    func receive(_ received: [DrakeItem]) {
        guard !received.isEmpty else { return }
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
        emit(text)
        if options.verbose { log("Received text") }
        if options.andExit { terminate() }
    }

    func dragEnded(accepted: Bool) {
        if options.verbose {
            log("Drag ended; accepted: \(accepted)")
        }
        if accepted && options.andExit {
            terminate()
        }
    }

    func terminate() {
        NSApp.terminate(nil)
    }

    // MARK: - Output

    /// Unbuffered so output is visible immediately when piped.
    func emit(_ line: String) {
        FileHandle.standardOutput.write(Data((line + "\n").utf8))
    }

    func log(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }
}
