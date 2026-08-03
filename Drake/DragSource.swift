//
//  DragSource.swift
//  Drake
//
//  SwiftUI's .onDrag carries one item and one representation. Dragging a whole
//  selection into arbitrary apps needs a real NSDraggingSession, so rows put a
//  transparent AppKit view on top that starts the session itself.
//

import AppKit
import SwiftUI

/// Offers each dragged item as a file URL, a URL, and as plain text.
///
/// Different destinations read different types: Finder and Electron apps such as
/// WhatsApp take `public.file-url`, browsers accept either the file URL or the
/// text, and editors and terminals want the text. Order here is priority order.
final class ItemPasteboardWriter: NSObject, NSPasteboardWriting {
    let item: DrakeItem

    init(item: DrakeItem) {
        self.item = item
    }

    nonisolated func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        if item.isFile {
            return [.fileURL, .URL, .string]
        }
        return [.URL, .string]
    }

    nonisolated func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        switch type {
        case .fileURL, .URL:
            return item.uri
        case .string:
            return item.dragText
        default:
            return nil
        }
    }
}

/// Transparent overlay that turns press-and-move into a dragging session and
/// reports plain clicks, double-clicks and right-clicks back to SwiftUI.
final class DragSourceNSView: NSView, NSDraggingSource {
    var itemsProvider: () -> [DrakeItem] = { [] }
    var imageProvider: (DrakeItem) -> NSImage? = { _ in nil }
    var onClick: (NSEvent.ModifierFlags) -> Void = { _ in }
    var onDoubleClick: () -> Void = {}
    var onDragEnded: (Bool) -> Void = { _ in }
    var menuProvider: () -> NSMenu? = { nil }
    var iconSize: CGFloat = 48

    private var mouseDownEvent: NSEvent?

    override var isOpaque: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
    }

    override func mouseDragged(with event: NSEvent) {
        guard let down = mouseDownEvent else { return }
        let dx = event.locationInWindow.x - down.locationInWindow.x
        let dy = event.locationInWindow.y - down.locationInWindow.y
        // A few points of slop so a sloppy click is still a click.
        guard (dx * dx + dy * dy) > 9 else { return }
        mouseDownEvent = nil
        beginDrag(with: down)
    }

    override func mouseUp(with event: NSEvent) {
        guard mouseDownEvent != nil else { return }
        mouseDownEvent = nil
        if event.clickCount >= 2 {
            onDoubleClick()
        } else {
            onClick(event.modifierFlags)
        }
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        // Right-clicking an unselected row should select it first.
        onClick([])
        return menuProvider()
    }

    private func beginDrag(with event: NSEvent) {
        let items = itemsProvider()
        guard !items.isEmpty else { return }

        let origin = convert(event.locationInWindow, from: nil)
        let size = NSSize(width: iconSize, height: iconSize)
        var draggingItems: [NSDraggingItem] = []

        for (index, item) in items.enumerated() {
            let draggingItem = NSDraggingItem(pasteboardWriter: ItemPasteboardWriter(item: item))
            // Fan the stack out slightly so a multi-item drag reads as a pile.
            let offset = CGFloat(min(index, 4)) * 4
            let frame = NSRect(
                x: origin.x - size.width / 2 + offset,
                y: origin.y - size.height / 2 - offset,
                width: size.width,
                height: size.height
            )
            draggingItem.setDraggingFrame(frame, contents: imageProvider(item) ?? item.systemIcon)
            draggingItems.append(draggingItem)
        }

        let session = beginDraggingSession(with: draggingItems, event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
        session.draggingFormation = items.count > 1 ? .stack : .default
    }

    // MARK: - NSDraggingSource

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        switch context {
        case .outsideApplication:
            return [.copy, .link, .generic]
        default:
            return [.copy]
        }
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        onDragEnded(!operation.isEmpty)
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool {
        false
    }
}

struct DragSourceOverlay: NSViewRepresentable {
    var items: () -> [DrakeItem]
    var image: (DrakeItem) -> NSImage? = { _ in nil }
    var iconSize: CGFloat = 48
    var onClick: (NSEvent.ModifierFlags) -> Void = { _ in }
    var onDoubleClick: () -> Void = {}
    var onDragEnded: (Bool) -> Void = { _ in }
    var menu: () -> NSMenu? = { nil }

    func makeNSView(context: Context) -> DragSourceNSView {
        let view = DragSourceNSView()
        apply(to: view)
        return view
    }

    func updateNSView(_ view: DragSourceNSView, context: Context) {
        apply(to: view)
    }

    private func apply(to view: DragSourceNSView) {
        view.itemsProvider = items
        view.imageProvider = image
        view.iconSize = iconSize
        view.onClick = onClick
        view.onDoubleClick = onDoubleClick
        view.onDragEnded = onDragEnded
        view.menuProvider = menu
    }
}

/// Builds an NSMenu from titles and closures, so rows keep a native context
/// menu without SwiftUI's .contextMenu fighting the overlay for the click.
enum ContextMenuBuilder {
    final class Action: NSObject {
        let handler: () -> Void

        init(handler: @escaping () -> Void) {
            self.handler = handler
        }

        @objc func invoke() {
            handler()
        }
    }

    /// Keeps the target objects alive for as long as the menu exists.
    private static var retained: [NSMenu: [Action]] = [:]

    static func make(_ entries: [(String, () -> Void)?]) -> NSMenu {
        let menu = NSMenu()
        var actions: [Action] = []
        for entry in entries {
            guard let entry else {
                menu.addItem(.separator())
                continue
            }
            let action = Action(handler: entry.1)
            let item = NSMenuItem(title: entry.0, action: #selector(Action.invoke), keyEquivalent: "")
            item.target = action
            menu.addItem(item)
            actions.append(action)
        }
        retained[menu] = actions
        // Menus are rebuilt on every right-click; keep only the recent ones.
        if retained.count > 32 {
            retained.removeAll()
            retained[menu] = actions
        }
        return menu
    }
}
