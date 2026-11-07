//
//  DragSource.swift
//  Drake
//
//  SwiftUI's .onDrag carries one item and one representation. Dragging a whole
//  selection into arbitrary apps needs a real NSDraggingSession, so rows put a
//  transparent AppKit view on top that starts the session itself. The same view
//  reports clicks, double-clicks, right-clicks and hover back to SwiftUI, and
//  shows the row's tooltip.
//

import AppKit
import SwiftUI

final class DragSourceNSView: NSView, NSDraggingSource {
    var itemsProvider: () -> [DrakeItem] = { [] }
    var imageProvider: (DrakeItem) -> NSImage = { Thumbnailer.shared.image(for: $0, size: 64) }
    var onClick: (NSEvent.ModifierFlags) -> Void = { _ in }
    var onDoubleClick: () -> Void = {}
    var onDragEnded: (Bool) -> Void = { _ in }
    var onHover: (Bool) -> Void = { _ in }
    var menuProvider: () -> NSMenu? = { nil }
    var iconSize: CGFloat = 48

    private var mouseDownEvent: NSEvent?

    /// Keeps file promises alive: a receiver may ask for the files after the
    /// session has ended, and a provider is only its own (weak) delegate.
    private static var promisesInFlight: [NSFilePromiseProvider] = []

    /// The drag in progress, so its pasteboard can be rewritten as it moves.
    private var draggedItems: [DrakeItem] = []
    private var draggedTextFiles = false
    private var offeringAttachments = false
    private var lastTargetCheck: TimeInterval = 0

    override var isOpaque: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // MARK: - Hover

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self
        ))
    }

    override func mouseEntered(with event: NSEvent) { onHover(true) }
    override func mouseExited(with event: NSEvent) { onHover(false) }

    // MARK: - Clicks

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

    /// The menu provider selects the row itself when it is not already part of
    /// the selection, so a right-click keeps a multiple selection intact.
    override func menu(for event: NSEvent) -> NSMenu? {
        menuProvider()
    }

    /// Rows sit inside the list, but if this overlay ever lands in a hosting
    /// layer outside it the responder chain would swallow the scroll.
    override func scrollWheel(with event: NSEvent) {
        if enclosingScrollView == nil, let scrollView = MarqueeSelectionNSView.scrollView(under: event) {
            scrollView.scrollWheel(with: event)
        } else {
            super.scrollWheel(with: event)
        }
    }

    // MARK: - Dragging

    private func beginDrag(with event: NSEvent) {
        let items = itemsProvider()
        guard !items.isEmpty else { return }

        draggedItems = items
        draggedTextFiles = items.contains { $0.dragsAsFilePromise }
        offeringAttachments = false
        lastTargetCheck = 0

        let origin = convert(event.locationInWindow, from: nil)
        let size = NSSize(width: iconSize, height: iconSize)
        let draggingItems = items.enumerated().map { index, item in
            let draggingItem = NSDraggingItem(pasteboardWriter: item.pasteboardWriter(asAttachment: false))
            // Fan the stack out slightly so a multi-item drag reads as a pile.
            let offset = CGFloat(min(index, 4)) * 4
            let frame = NSRect(
                x: origin.x - size.width / 2 + offset,
                y: origin.y - size.height / 2 - offset,
                width: size.width,
                height: size.height
            )
            draggingItem.setDraggingFrame(frame, contents: imageProvider(item))
            return draggingItem
        }

        Log.drag.info("Drag started with \(items.count) item(s)")
        let session = beginDraggingSession(with: draggingItems, event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
        session.draggingFormation = items.count > 1 ? .stack : .default
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        switch context {
        case .outsideApplication: [.copy, .link, .generic]
        default: [.copy]
        }
    }

    /// Offers text files as attachments while the drag is near an app that
    /// needs them, and as URLs everywhere else.
    func draggingSession(_ session: NSDraggingSession, movedTo screenPoint: NSPoint) {
        guard draggedTextFiles else { return }
        // The window list costs a few milliseconds; mouse moves come faster.
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastTargetCheck > 0.03 else { return }
        lastTargetCheck = now

        let wanted = DropTargetApp.wantsAttachments(near: screenPoint)
        guard wanted != offeringAttachments else { return }
        offeringAttachments = wanted
        Log.drag.debug(wanted ? "Offering text files as attachments" : "Offering text files as URLs")

        let writers = draggedItems.map { $0.pasteboardWriter(asAttachment: wanted) }
        Self.promisesInFlight = writers.compactMap { $0 as? NSFilePromiseProvider }
        session.draggingPasteboard.clearContents()
        session.draggingPasteboard.writeObjects(writers)
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        onDragEnded(!operation.isEmpty)
    }
}

struct DragSourceOverlay: NSViewRepresentable {
    var items: () -> [DrakeItem]
    var image: ((DrakeItem) -> NSImage)?
    var iconSize: CGFloat = 48
    var toolTip: String?
    var onClick: (NSEvent.ModifierFlags) -> Void = { _ in }
    var onDoubleClick: () -> Void = {}
    var onDragEnded: (Bool) -> Void = { _ in }
    var onHover: (Bool) -> Void = { _ in }
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
        if let image { view.imageProvider = image }
        view.iconSize = iconSize
        view.toolTip = toolTip
        view.onClick = onClick
        view.onDoubleClick = onDoubleClick
        view.onDragEnded = onDragEnded
        view.onHover = onHover
        view.menuProvider = menu
    }
}
