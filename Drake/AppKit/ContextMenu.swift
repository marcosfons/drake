//
//  ContextMenu.swift
//  Drake
//
//  Builds an NSMenu from titles and closures, so rows keep a native context
//  menu without SwiftUI's .contextMenu fighting the drag overlay for the click.
//

import AppKit

enum ContextMenu {
    /// A menu entry, or a separator.
    enum Entry {
        case action(String, () -> Void)
        case separator
    }

    /// The closure behind one item. A menu item's target is weak, so the item
    /// also holds it as its represented object, which keeps it alive exactly as
    /// long as the menu.
    private final class Handler: NSObject {
        let action: () -> Void

        init(_ action: @escaping () -> Void) {
            self.action = action
        }

        @objc func invoke() {
            action()
        }
    }

    static func make(_ entries: [Entry]) -> NSMenu {
        let menu = NSMenu()
        for entry in entries {
            switch entry {
            case .separator:
                menu.addItem(.separator())
            case .action(let title, let action):
                let handler = Handler(action)
                let item = NSMenuItem(title: title, action: #selector(Handler.invoke), keyEquivalent: "")
                item.target = handler
                item.representedObject = handler
                menu.addItem(item)
            }
        }
        return menu
    }
}
