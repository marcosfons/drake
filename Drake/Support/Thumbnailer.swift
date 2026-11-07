//
//  Thumbnailer.swift
//  Drake
//
//  Real Quick Look thumbnails where the file has one (images, video), the
//  Finder icon otherwise - dragon's pixbuf-then-theme-icon rule. Both are
//  cached, so a row redrawing never asks Quick Look or NSWorkspace again.
//

import AppKit
import QuickLookThumbnailing
import UniformTypeIdentifiers

final class Thumbnailer {
    static let shared = Thumbnailer()

    private var thumbnails: [String: NSImage] = [:]
    private var finderIcons: [String: NSImage] = [:]
    private var inFlight: Set<String> = []

    private func key(for item: DrakeItem, size: CGFloat) -> String {
        "\(item.uri)|\(Int(size))"
    }

    /// Best image available right now: a cached thumbnail, else Finder's icon.
    /// Used for drag images, which cannot wait.
    func image(for item: DrakeItem, size: CGFloat) -> NSImage {
        thumbnails[key(for: item, size: size)] ?? finderIcon(for: item)
    }

    /// Finder's icon for the item, generic when the file is gone.
    func finderIcon(for item: DrakeItem) -> NSImage {
        if let cached = finderIcons[item.uri] { return cached }
        let icon: NSImage
        if let url = item.fileURL {
            icon = item.exists
                ? NSWorkspace.shared.icon(forFile: url.path)
                : NSWorkspace.shared.icon(for: .item)
        } else {
            icon = NSWorkspace.shared.icon(for: .url)
        }
        finderIcons[item.uri] = icon
        return icon
    }

    /// Only pictures and video get a content thumbnail. Quick Look also
    /// renders text, code and PDFs, but at row size those come out as blank
    /// white pages, so the type icon reads better.
    nonisolated static func wantsThumbnail(for type: UTType?) -> Bool {
        guard let type else { return false }
        return type.conforms(to: .image) || type.conforms(to: .movie)
    }

    /// Generates a content thumbnail, returning nil when the file has none.
    func thumbnail(for item: DrakeItem, info: FileInfo, size: CGFloat, scale: CGFloat) async -> NSImage? {
        let cacheKey = key(for: item, size: size)
        if let cached = thumbnails[cacheKey] { return cached }
        guard let url = item.fileURL, info.exists, !info.isDirectory,
              Self.wantsThumbnail(for: info.contentType),
              !inFlight.contains(cacheKey)
        else { return nil }
        inFlight.insert(cacheKey)
        defer { inFlight.remove(cacheKey) }

        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: size, height: size),
            scale: scale,
            representationTypes: .thumbnail
        )
        request.iconMode = false

        do {
            let representation = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            let cgImage = representation.cgImage
            let image = NSImage(
                cgImage: cgImage,
                size: NSSize(width: CGFloat(cgImage.width) / scale, height: CGFloat(cgImage.height) / scale)
            )
            thumbnails[cacheKey] = image
            return image
        } catch {
            // Common for files Quick Look has no generator for; the type icon stands in.
            Log.thumbnails.debug("No thumbnail for \(url.lastPathComponent): \(error.localizedDescription)")
            return nil
        }
    }
}
