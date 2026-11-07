//
//  MainMenu.swift
//  Drake
//
//  The menu bar. The app is built without a nib, so it is assembled here.
//
//  Every app command is sent to the first responder (nil target) and lands on
//  the AppDelegate at the end of the responder chain. That way a focused text
//  field - the history search, a rename - gets Copy, Select All and friends
//  first, and the list gets them otherwise.
//

import AppKit

enum MainMenu {
    static func build() -> NSMenu {
        let main = NSMenu()
        main.addItem(submenu: appMenu())
        main.addItem(submenu: fileMenu())
        main.addItem(submenu: editMenu())
        main.addItem(submenu: historyMenu())

        let window = windowMenu()
        main.addItem(submenu: window)
        NSApp.windowsMenu = window

        let help = helpMenu()
        main.addItem(submenu: help)
        NSApp.helpMenu = help
        return main
    }

    private static func appMenu() -> NSMenu {
        let menu = NSMenu(title: "Drake")
        menu.addItem("About Drake", #selector(AppDelegate.showAbout(_:)))
        menu.addItem(.separator())

        let services = NSMenu(title: "Services")
        menu.addItem(withTitle: "Services", action: nil, keyEquivalent: "").submenu = services
        NSApp.servicesMenu = services
        menu.addItem(.separator())

        menu.addItem("Hide Drake", #selector(NSApplication.hide(_:)), "h")
        menu.addItem("Hide Others", #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option])
        menu.addItem("Show All", #selector(NSApplication.unhideAllApplications(_:)))
        menu.addItem(.separator())
        menu.addItem("Quit Drake", #selector(NSApplication.terminate(_:)), "q")
        return menu
    }

    private static func fileMenu() -> NSMenu {
        let menu = NSMenu(title: "File")
        menu.addItem("Open", #selector(AppDelegate.openSelected(_:)), "o")
        menu.addItem("Reveal in Finder", #selector(AppDelegate.revealSelected(_:)), "r")
        menu.addItem(.separator())
        menu.addItem("Close Window", #selector(NSWindow.performClose(_:)), "w")
        return menu
    }

    private static func editMenu() -> NSMenu {
        let menu = NSMenu(title: "Edit")
        menu.addItem("Undo", Selector(("undo:")), "z")
        menu.addItem("Redo", Selector(("redo:")), "z", [.command, .shift])
        menu.addItem(.separator())
        menu.addItem("Cut", #selector(NSText.cut(_:)), "x")
        // In the list, Copy copies the selected paths (see AppDelegate.copy).
        menu.addItem("Copy", #selector(NSText.copy(_:)), "c")
        menu.addItem("Paste", #selector(NSText.paste(_:)), "v")
        menu.addItem("Select All", #selector(NSText.selectAll(_:)), "a")
        menu.addItem(.separator())
        // A bare Delete key. Disabled while text is being edited, so the key
        // still reaches the text field.
        menu.addItem("Remove from List", #selector(AppDelegate.removeSelectedItems(_:)), "\u{8}", [])
        menu.addItem(.separator())
        menu.addItem("Find…", #selector(AppDelegate.findInHistory(_:)), "f")
        return menu
    }

    private static func historyMenu() -> NSMenu {
        let menu = NSMenu(title: "History")
        menu.addItem("Show History", #selector(AppDelegate.showHistory(_:)), "y")
        menu.addItem("Back", #selector(AppDelegate.goBack(_:)), "[")
        menu.addItem(.separator())
        menu.addItem("Clear History…", #selector(AppDelegate.clearHistory(_:)))
        return menu
    }

    private static func windowMenu() -> NSMenu {
        let menu = NSMenu(title: "Window")
        menu.addItem("Minimize", #selector(NSWindow.performMiniaturize(_:)), "m")
        menu.addItem("Zoom", #selector(NSWindow.performZoom(_:)))
        menu.addItem(.separator())
        menu.addItem("Keep on Top", #selector(AppDelegate.toggleKeepOnTop(_:)))
        menu.addItem(.separator())
        menu.addItem("Bring All to Front", #selector(NSApplication.arrangeInFront(_:)))
        return menu
    }

    private static func helpMenu() -> NSMenu {
        let menu = NSMenu(title: "Help")
        menu.addItem("Drake Help", #selector(AppDelegate.showHelp(_:)), "?")
        menu.addItem("Show Problem Log", #selector(AppDelegate.showProblemLog(_:)))
        menu.addItem(.separator())
        menu.addItem("dragon, the Original, on GitHub", #selector(AppDelegate.showDragonProject(_:)))
        return menu
    }
}

private extension NSMenu {
    @discardableResult
    func addItem(
        _ title: String,
        _ action: Selector,
        _ key: String = "",
        _ modifiers: NSEvent.ModifierFlags = .command
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        addItem(item)
        return item
    }

    func addItem(submenu: NSMenu) {
        let item = NSMenuItem(title: submenu.title, action: nil, keyEquivalent: "")
        item.submenu = submenu
        addItem(item)
    }
}

// MARK: - Commands

extension AppDelegate: NSMenuItemValidation {
    static let dragonURL = URL(string: "https://github.com/mwh/dragon")!

    @objc func showAbout(_ sender: Any?) {
        let credits = NSMutableAttributedString(
            string: "Drag and drop for the command line, with a history of past runs.\n",
            attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor]
        )
        credits.append(NSAttributedString(
            string: "Modelled on dragon by Michael Homer.",
            attributes: [.font: NSFont.systemFont(ofSize: 11), .link: Self.dragonURL]
        ))
        let centred = NSMutableParagraphStyle()
        centred.alignment = .center
        credits.addAttribute(.paragraphStyle, value: centred, range: NSRange(location: 0, length: credits.length))
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }

    @objc func openSelected(_ sender: Any?) {
        model.openSelected()
    }

    @objc func revealSelected(_ sender: Any?) {
        model.revealSelected()
    }

    /// Reached only when no text field has focus: copies the selected paths.
    @objc func copy(_ sender: Any?) {
        model.copySelectedPaths()
    }

    @objc func selectAll(_ sender: Any?) {
        model.selectAll()
    }

    @objc func removeSelectedItems(_ sender: Any?) {
        model.removeSelected()
    }

    /// ⌘F searches the history from anywhere.
    @objc func findInHistory(_ sender: Any?) {
        if model.mode != .history { model.showHistory() }
        // After the toolbar has shown the search field for the new mode.
        Task { toolbar.beginSearch() }
    }

    @objc func showHistory(_ sender: Any?) {
        model.showHistory()
    }

    @objc func goBack(_ sender: Any?) {
        model.returnFromHistory()
    }

    @objc func clearHistory(_ sender: Any?) {
        guard let window else { return }
        let alert = NSAlert()
        alert.messageText = "Clear History?"
        alert.informativeText = "Every run except pinned ones is removed. This cannot be undone."
        alert.addButton(withTitle: "Clear History").hasDestructiveAction = true
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: window) { [model] response in
            guard response == .alertFirstButtonReturn else { return }
            model.history.clear()
            Log.history.info("History cleared")
        }
    }

    @objc func toggleKeepOnTop(_ sender: Any?) {
        guard let window else { return }
        window.level = window.level == .floating ? .normal : .floating
    }

    /// The man page, in Terminal.
    @objc func showHelp(_ sender: Any?) {
        guard let url = URL(string: "x-man-page://\(Options.programName)"),
              NSWorkspace.shared.open(url)
        else {
            Log.app.warning("Could not open the man page")
            return
        }
    }

    /// The problem log opens in Console, which also lists it under Log Reports.
    @objc func showProblemLog(_ sender: Any?) {
        ProblemLog.shared.flush()
        NSWorkspace.shared.open(ProblemLog.shared.fileURL)
    }

    @objc func showDragonProject(_ sender: Any?) {
        NSWorkspace.shared.open(Self.dragonURL)
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        let hasList = model.mode != .history && !model.items.isEmpty

        switch menuItem.action {
        case #selector(openSelected(_:)),
             #selector(revealSelected(_:)),
             #selector(copy(_:)),
             #selector(selectAll(_:)):
            return hasList
        case #selector(removeSelectedItems(_:)):
            return hasList && !model.selection.isEmpty && !(window?.isEditingText ?? false)
        case #selector(showHistory(_:)):
            return model.mode != .history
        case #selector(goBack(_:)):
            return model.canReturnFromHistory
        case #selector(clearHistory(_:)):
            return model.history.entries.contains { !$0.pinned }
        case #selector(toggleKeepOnTop(_:)):
            menuItem.state = window?.level == .floating ? .on : .off
            return window != nil
        case #selector(showProblemLog(_:)):
            ProblemLog.shared.flush()
            return FileManager.default.fileExists(atPath: ProblemLog.shared.fileURL.path)
        default:
            return true
        }
    }
}
