//
//  MainMenu.swift
//  Drake
//
//  The app is built without a nib, so the menu bar is assembled here. Real menu
//  items are used rather than SwiftUI shortcuts so ⌘C, ⌘A and friends work no
//  matter where focus happens to be.
//

import AppKit

@MainActor
final class MenuActions: NSObject, NSMenuItemValidation {
    private let model: AppModel

    init(model: AppModel) {
        self.model = model
        super.init()
    }

    @objc func openSelected(_ sender: Any?) {
        model.openSelected()
    }

    @objc func revealSelected(_ sender: Any?) {
        model.revealSelected()
    }

    @objc func copyPaths(_ sender: Any?) {
        model.copySelectedPaths()
    }

    @objc func removeSelected(_ sender: Any?) {
        model.removeSelected()
    }

    @objc func selectAllItems(_ sender: Any?) {
        model.selectAll()
    }

    @objc func showHistory(_ sender: Any?) {
        model.showHistory()
    }

    @objc func returnFromHistory(_ sender: Any?) {
        model.returnFromHistory()
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(showHistory(_:)):
            return model.mode != .history
        case #selector(returnFromHistory(_:)):
            return model.canReturnFromHistory
        case #selector(openSelected(_:)),
             #selector(revealSelected(_:)),
             #selector(copyPaths(_:)),
             #selector(selectAllItems(_:)):
            return !model.items.isEmpty
        case #selector(removeSelected(_:)):
            return !model.selection.isEmpty
        default:
            return true
        }
    }
}

enum MainMenu {
    static func build(actions: MenuActions) -> NSMenu {
        let appName = "Drake"
        let mainMenu = NSMenu()

        // Application menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(
            withTitle: "About \(appName)",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "Hide \(appName)",
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        )
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "Quit \(appName)",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // File menu
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        add(to: fileMenu, "Open", #selector(MenuActions.openSelected(_:)), "o", actions)
        add(to: fileMenu, "Reveal in Finder", #selector(MenuActions.revealSelected(_:)), "r", actions)
        fileMenu.addItem(.separator())
        add(to: fileMenu, "Show History", #selector(MenuActions.showHistory(_:)), "y", actions)
        add(to: fileMenu, "Back to Files", #selector(MenuActions.returnFromHistory(_:)), "[", actions)
        fileMenu.addItem(.separator())
        fileMenu.addItem(
            withTitle: "Close Window",
            action: #selector(NSWindow.performClose(_:)),
            keyEquivalent: "w"
        )
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        // Edit menu — the text field in the history search needs the standard
        // responder-chain items, plus our list commands.
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        add(to: editMenu, "Copy Path", #selector(MenuActions.copyPaths(_:)), "c", actions)
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(.separator())
        add(to: editMenu, "Select All", #selector(MenuActions.selectAllItems(_:)), "a", actions)
        let remove = add(to: editMenu, "Remove from List", #selector(MenuActions.removeSelected(_:)), "\u{8}", actions)
        remove.keyEquivalentModifierMask = []
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // Window menu
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(
            withTitle: "Minimize",
            action: #selector(NSWindow.performMiniaturize(_:)),
            keyEquivalent: "m"
        )
        windowMenu.addItem(
            withTitle: "Zoom",
            action: #selector(NSWindow.performZoom(_:)),
            keyEquivalent: ""
        )
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        return mainMenu
    }

    @discardableResult
    private static func add(
        to menu: NSMenu,
        _ title: String,
        _ action: Selector,
        _ key: String,
        _ target: MenuActions
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = target
        menu.addItem(item)
        return item
    }
}
