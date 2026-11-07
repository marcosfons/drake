//
//  ItemIcon.swift
//  Drake
//
//  The best available picture of an item: a Quick Look thumbnail where the
//  file has one, otherwise a per-type symbol, otherwise Finder's icon.
//

import SwiftUI

struct ItemIcon: View {
    let item: DrakeItem
    let info: FileInfo
    let size: CGFloat

    @Environment(\.displayScale) private var displayScale
    @State private var thumbnail: NSImage?

    var body: some View {
        content
            .frame(width: size, height: size)
            .opacity(info.exists ? 1 : 0.5)
            .task(id: item.uri) {
                thumbnail = await Thumbnailer.shared.thumbnail(
                    for: item,
                    info: info,
                    size: size,
                    scale: displayScale
                )
            }
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        if let thumbnail {
            Image(nsImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(.rect(cornerRadius: size * 0.14, style: .continuous))
        } else if let typeIcon = FileTypeIcons.icon(for: item, info: info) {
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .fill(typeIcon.color.opacity(0.16))
                .overlay {
                    Image(systemName: typeIcon.symbol)
                        .font(.system(size: size * 0.48, weight: .semibold))
                        .foregroundStyle(typeIcon.color)
                }
        } else {
            Image(nsImage: Thumbnailer.shared.finderIcon(for: item))
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }
}
