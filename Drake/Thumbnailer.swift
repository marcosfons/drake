//
//  Thumbnailer.swift
//  Drake
//
//  Real Quick Look thumbnails where the file has one (images, PDFs, video),
//  the Finder document icon otherwise — dragon's pixbuf-then-theme-icon rule.
//

import AppKit
import Observation
import QuickLookThumbnailing
import SwiftUI

@Observable
final class Thumbnailer {
    static let shared = Thumbnailer()

    private var cache: [String: NSImage] = [:]
    private var inFlight: Set<String> = []

    private func key(for item: DrakeItem, size: CGFloat) -> String {
        "\(item.uri)|\(Int(size))"
    }

    /// Immediately available image: cached thumbnail, else the system icon.
    func icon(for item: DrakeItem, size: CGFloat) -> NSImage {
        cache[key(for: item, size: size)] ?? item.systemIcon
    }

    /// Generates a content thumbnail, returning nil when the file has none.
    func thumbnail(for item: DrakeItem, size: CGFloat) async -> NSImage? {
        let cacheKey = key(for: item, size: size)
        if let cached = cache[cacheKey] { return cached }
        guard let url = item.fileURL, item.exists, !item.isDirectory else { return nil }
        guard !inFlight.contains(cacheKey) else { return nil }
        inFlight.insert(cacheKey)
        defer { inFlight.remove(cacheKey) }

        let scale = NSScreen.main?.backingScaleFactor ?? 2
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
            cache[cacheKey] = image
            return image
        } catch {
            // No thumbnail representation — the system icon stands in.
            return nil
        }
    }
}

/// Shows the best available representation of an item: a Quick Look thumbnail
/// where the file has one, otherwise a per-type symbol, otherwise Finder's icon.
struct ItemIcon: View {
    let item: DrakeItem
    var size: CGFloat

    @State private var thumbnail: NSImage?

    private var typeIcon: FileTypeIcon? { FileTypeIcons.icon(for: item) }

    var body: some View {
        content
            .frame(width: size, height: size)
            .opacity(item.exists ? 1 : 0.55)
            .task(id: item.uri) {
                thumbnail = await Thumbnailer.shared.thumbnail(for: item, size: max(size * 2, 64))
            }
    }

    @ViewBuilder
    private var content: some View {
        if let thumbnail {
            Image(nsImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.12))
        } else if let typeIcon {
            RoundedRectangle(cornerRadius: size * 0.24)
                .fill(typeIcon.color.opacity(0.15))
                .overlay {
                    Image(systemName: typeIcon.symbol)
                        .font(.system(size: size * 0.5, weight: .medium))
                        .foregroundStyle(typeIcon.color)
                }
        } else {
            Image(nsImage: item.systemIcon)
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }
}
