//
//  WindowToolbar.swift
//  Drake
//
//  The compact toolbar beside the window title. One set of items, shown or
//  hidden per mode:
//
//  - Back (leading), in the history browser when there is a screen to return to.
//  - Search, in the history browser.
//  - History, everywhere else once there is history to show.
//

import AppKit

final class WindowToolbar: NSObject, NSToolbarDelegate {
    let toolbar = NSToolbar(identifier: "DrakeToolbar")
    private let model: AppModel

    private var backItem: NSToolbarItem?
    private var searchItem: NSSearchToolbarItem?
    private var historyItem: NSToolbarItem?

    private enum Identifier {
        static let back = NSToolbarItem.Identifier("back")
        static let search = NSToolbarItem.Identifier("search")
        static let history = NSToolbarItem.Identifier("history")
    }

    init(model: AppModel) {
        self.model = model
        super.init()
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
    }

    /// Shows the items that apply to the current mode.
    func update() {
        backItem?.isHidden = !model.canReturnFromHistory
        searchItem?.isHidden = model.mode != .history
        historyItem?.isHidden = !model.canGoBackToHistory
        if model.mode != .history, let field = searchItem?.searchField, !field.stringValue.isEmpty {
            field.stringValue = ""
            model.historyQuery = ""
        }
    }

    /// Puts the cursor in the history search field (⌘F).
    func beginSearch() {
        searchItem?.beginSearchInteraction()
    }

    // MARK: - Actions

    @objc private func goBack(_ sender: Any?) {
        model.returnFromHistory()
    }

    @objc private func showHistory(_ sender: Any?) {
        model.showHistory()
    }

    @objc private func searchChanged(_ sender: NSSearchField) {
        model.historyQuery = sender.stringValue
    }

    // MARK: - NSToolbarDelegate

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Identifier.back, .flexibleSpace, Identifier.search, Identifier.history]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier identifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        switch identifier {
        case Identifier.back:
            let item = button(
                identifier,
                symbol: "chevron.backward",
                label: "Back",
                toolTip: "Back to the files this run opened with (⌘[)",
                action: #selector(goBack(_:))
            )
            item.isNavigational = true
            backItem = item
            return item

        case Identifier.search:
            let item = NSSearchToolbarItem(itemIdentifier: identifier)
            item.label = "Search"
            item.preferredWidthForSearchField = 200
            let field = item.searchField
            field.placeholderString = "Search History"
            field.sendsSearchStringImmediately = true
            field.target = self
            field.action = #selector(searchChanged(_:))
            searchItem = item
            return item

        case Identifier.history:
            let item = button(
                identifier,
                symbol: "clock.arrow.circlepath",
                label: "History",
                toolTip: "Show previous runs (⌘Y)",
                action: #selector(showHistory(_:))
            )
            historyItem = item
            return item

        default:
            return nil
        }
    }

    private func button(
        _ identifier: NSToolbarItem.Identifier,
        symbol: String,
        label: String,
        toolTip: String,
        action: Selector
    ) -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        item.label = label
        item.toolTip = toolTip
        item.isBordered = true
        item.target = self
        item.action = action
        return item
    }
}
