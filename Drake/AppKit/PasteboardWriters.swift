//
//  PasteboardWriters.swift
//  Drake
//
//  What a dragged item puts on the pasteboard. Which types each item offers is
//  load-bearing: receivers accept or refuse a drag at drag-enter by the types
//  it advertises.
//

import AppKit
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

    func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        item.isFile ? [.fileURL] : [.URL, .string]
    }

    func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        switch type {
        case .fileURL, .URL: item.dragURI
        case .string: item.dragText
        default: nil
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
            Log.drag.info("Delivered \(name) as an attachment")
            completionHandler(nil)
        } catch {
            Log.drag.error("Could not copy \(source.path) for a drop: \(error)")
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
        guard isFile else { return false }
        let info = FileInfo(url: fileURL)
        guard info.exists, !info.isDirectory else { return false }
        return info.contentType?.conforms(to: .text) ?? false
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
