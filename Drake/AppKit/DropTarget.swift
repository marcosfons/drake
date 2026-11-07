//
//  DropTarget.swift
//  Drake
//
//  Target mode's receiving end. Handled in AppKit so file URLs, remote URLs and
//  plain text can be told apart the way dragon's drag-data-received does.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum DroppedPayload {
    case items([DrakeItem])
    case text(String)
}

final class DropTargetNSView: NSView {
    var onDrop: (DroppedPayload) -> Void = { _ in }
    var onHighlight: (Bool) -> Void = { _ in }

    private static let acceptedTypes: [NSPasteboard.PasteboardType] = [
        .fileURL,
        .URL,
        .string,
        NSPasteboard.PasteboardType("NSFilenamesPboardType"),
    ]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes(Self.acceptedTypes)
    }

    required init?(coder: NSCoder) {
        fatalError("DropTargetNSView is only created in code")
    }

    override var isOpaque: Bool { false }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        onHighlight(true)
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onHighlight(false)
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        onHighlight(false)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        onHighlight(false)
        let pasteboard = sender.draggingPasteboard

        // URLs win over text: a file dragged from Finder carries both, and the
        // file is what the user meant.
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: false]
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL],
           !urls.isEmpty {
            let items = urls.map { url -> DrakeItem in
                url.isFileURL ? .file(at: url.standardizedFileURL) : .uri(url.absoluteString)
            }
            onDrop(.items(items))
            return true
        }

        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            onDrop(.text(text))
            return true
        }

        let types = pasteboard.types?.map(\.rawValue).joined(separator: ", ") ?? "none"
        Log.drop.warning("Refused a drop with nothing readable; types: \(types)")
        return false
    }
}

struct DropTargetOverlay: NSViewRepresentable {
    var onDrop: (DroppedPayload) -> Void
    var onHighlight: (Bool) -> Void

    func makeNSView(context: Context) -> DropTargetNSView {
        let view = DropTargetNSView()
        view.onDrop = onDrop
        view.onHighlight = onHighlight
        return view
    }

    func updateNSView(_ view: DropTargetNSView, context: Context) {
        view.onDrop = onDrop
        view.onHighlight = onHighlight
    }
}
