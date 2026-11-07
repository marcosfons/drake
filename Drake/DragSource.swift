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
import UniformTypeIdentifiers

/// Offers a file as a file URL alone, and a bare URI as a URL and as plain text.
///
/// A file deliberately offers nothing but `public.file-url`, which is exactly
/// what Finder puts on the pasteboard - the system synthesises the legacy
/// flavours (`NSFilenamesPboardType`, `Apple URL pasteboard type`) from it, so
/// old and new receivers are both covered.
///
/// Adding `public.utf8-plain-text` alongside it looks harmless and is not.
/// WhatsApp for Mac is a sandboxed Catalyst app, so its drops arrive through
/// UIKit's item-provider bridge, and a file drag that also advertises text is
/// refused outright at drag-enter: no highlight, no drop. Matching Finder's type
/// set exactly is what makes it accept the drag. The cost is that a target which
/// takes dragged text but not dragged files no longer receives the path - the
/// same trade Finder itself makes.
///
/// A bare URI such as `https://…` has no file to offer, so it keeps URL and
/// text, which are the only ways a target can take it.
nonisolated final class ItemPasteboardWriter: NSObject, NSPasteboardWriting {
    let item: DrakeItem

    init(item: DrakeItem) {
        self.item = item
    }

    nonisolated func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        item.isFile ? [.fileURL] : [.URL, .string]
    }

    nonisolated func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        switch type {
        case .fileURL, .URL:
            return item.dragURI
        case .string:
            return item.dragText
        default:
            return nil
        }
    }
}

/// Hands a text file over as a promise of generic data, fulfilled by copying
/// the file wherever the receiver asks.
///
/// WhatsApp refuses any drag whose item looks like text, and a file URL
/// carries its file's type: Markdown, JSON, CSV and source code all conform to
/// `public.text`, so not even Finder can drop a `.md` file there. A promise
/// declares only `public.data`, which arrives as an ordinary attachment.
///
/// A promise gives no path, though, so Terminal and editors need the URL.
/// Drags therefore start with URLs and switch to promises only while over an
/// app that needs them; see DropTargetApp.
nonisolated final class DataFilePromise: NSFilePromiseProvider, NSFilePromiseProviderDelegate,
    @unchecked Sendable
{
    /// The real file, symlinks resolved, and the name the copy is given.
    let source: URL
    let name: String

    private static let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        return queue
    }()

    init(source: URL, name: String) {
        self.source = source
        self.name = name
        super.init()
        fileType = UTType.data.identifier
        delegate = self
    }

    func filePromiseProvider(_ provider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
        name
    }

    func filePromiseProvider(
        _ provider: NSFilePromiseProvider,
        writePromiseTo url: URL,
        completionHandler: @escaping (Error?) -> Void
    ) {
        do {
            try FileManager.default.copyItem(at: source, to: url)
            completionHandler(nil)
        } catch {
            completionHandler(error)
        }
    }

    func operationQueue(for provider: NSFilePromiseProvider) -> OperationQueue {
        Self.queue
    }
}

nonisolated extension DrakeItem {
    /// Existing text files, which go out as a `DataFilePromise` when the drag
    /// is over an app that refuses them as URLs.
    var dragsAsFilePromise: Bool {
        guard let fileURL, exists, !isDirectory else { return false }
        let type = (try? fileURL.resourceValues(forKeys: [.contentTypeKey]))?.contentType
            ?? UTType(filenameExtension: fileURL.pathExtension)
        return type?.conforms(to: .text) ?? false
    }

    /// What this item puts on the dragging pasteboard: an attachment copy for
    /// a text file when `asAttachment`, otherwise its URL.
    func pasteboardWriter(asAttachment: Bool) -> NSPasteboardWriting {
        if asAttachment, dragsAsFilePromise, let real = URL(string: dragURI), let fileURL {
            return DataFilePromise(source: real, name: fileURL.lastPathComponent)
        }
        return ItemPasteboardWriter(item: self)
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

    /// Rows sit inside the list, but if this overlay ever lands in a hosting
    /// layer outside it the responder chain would swallow the scroll.
    override func scrollWheel(with event: NSEvent) {
        if enclosingScrollView == nil, let scrollView = MarqueeSelectionNSView.scrollView(under: event) {
            scrollView.scrollWheel(with: event)
        } else {
            super.scrollWheel(with: event)
        }
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        // Right-clicking an unselected row should select it first.
        onClick([])
        return menuProvider()
    }

    private static var promisesInFlight: [NSFilePromiseProvider] = []

    /// The drag in progress, so its pasteboard can be rewritten as it moves.
    private var draggedItems: [DrakeItem] = []
    private var draggedTextFiles = false
    private var offeringAttachments = false
    private var lastTargetCheck: TimeInterval = 0

    private func beginDrag(with event: NSEvent) {
        let items = itemsProvider()
        guard !items.isEmpty else { return }

        let origin = convert(event.locationInWindow, from: nil)
        let size = NSSize(width: iconSize, height: iconSize)
        var draggingItems: [NSDraggingItem] = []

        draggedItems = items
        draggedTextFiles = items.contains { $0.dragsAsFilePromise }
        offeringAttachments = false
        lastTargetCheck = 0

        for (index, item) in items.enumerated() {
            let draggingItem = NSDraggingItem(pasteboardWriter: item.pasteboardWriter(asAttachment: false))
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

        let writers = draggedItems.map { $0.pasteboardWriter(asAttachment: wanted) }
        // A receiver may ask for the files after the session has ended, and a
        // provider is its own (weak) delegate, so keep the latest ones alive.
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
