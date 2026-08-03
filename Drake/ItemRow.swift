//
//  ItemRow.swift
//  Drake
//
//  One draggable row, shared by the source list and by expanded history entries.
//

import AppKit
import SwiftUI

struct ItemRow: View {
    let item: DrakeItem
    var nameStyle: NameStyle = .relative
    var baseDirectory: URL
    var iconSize: CGFloat = 32
    var isSelected: Bool = false
    var showsDetail: Bool = true

    /// What a drag starting here carries - usually the whole selection.
    var dragItems: () -> [DrakeItem]
    var onClick: (NSEvent.ModifierFlags) -> Void
    var onDoubleClick: () -> Void = {}
    var onDragEnded: (Bool) -> Void = { _ in }
    var menu: () -> NSMenu? = { nil }

    var body: some View {
        HStack(spacing: 10) {
            ItemIcon(item: item, size: iconSize)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(item.label(style: nameStyle, relativeTo: baseDirectory))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if !item.exists {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(isSelected ? .white : .orange)
                            .help("This file no longer exists")
                    }
                }
                if showsDetail {
                    Text(item.detail(relativeTo: baseDirectory))
                        .font(.caption)
                        .foregroundStyle(isSelected ? AnyShapeStyle(.white.opacity(0.8)) : AnyShapeStyle(.secondary))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer(minLength: 0)
        }
        .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
        .padding(.horizontal, 8)
        .frame(height: Metrics.rowHeight(iconSize: iconSize))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.clear))
        }
        .contentShape(Rectangle())
        .help(item.fileURL?.path ?? item.uri)
        .overlay {
            DragSourceOverlay(
                items: dragItems,
                image: { Thumbnailer.shared.icon(for: $0, size: 64) },
                iconSize: max(iconSize, 40),
                onClick: onClick,
                onDoubleClick: onDoubleClick,
                onDragEnded: onDragEnded,
                menu: menu
            )
        }
    }
}

/// Icon-only tile for `--icon-only`.
struct ItemTile: View {
    let item: DrakeItem
    var baseDirectory: URL
    var iconSize: CGFloat
    var isSelected: Bool

    var dragItems: () -> [DrakeItem]
    var onClick: (NSEvent.ModifierFlags) -> Void
    var onDoubleClick: () -> Void = {}
    var onDragEnded: (Bool) -> Void = { _ in }
    var menu: () -> NSMenu? = { nil }

    var body: some View {
        ItemIcon(item: item, size: iconSize)
            .padding(6)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? AnyShapeStyle(Color.accentColor.opacity(0.8)) : AnyShapeStyle(.clear))
            }
            .contentShape(Rectangle())
            .help(item.fileURL?.path ?? item.uri)
            .overlay {
                DragSourceOverlay(
                    items: dragItems,
                    image: { Thumbnailer.shared.icon(for: $0, size: iconSize * 2) },
                    iconSize: iconSize,
                    onClick: onClick,
                    onDoubleClick: onDoubleClick,
                    onDragEnded: onDragEnded,
                    menu: menu
                )
            }
    }
}

/// The "drag everything at once" control used by `--all` and `--all-compact`.
struct DragAllTile: View {
    let items: [DrakeItem]
    var compact: Bool
    var onDragEnded: (Bool) -> Void = { _ in }

    private var draggable: [DrakeItem] { items.filter(\.exists) }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(compact ? .system(size: 34) : .system(size: 18))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(draggable.count) \(draggable.count == 1 ? "file" : "files")")
                    .font(compact ? .title3 : .body)
                    .fontWeight(.medium)
                Text("Drag from here to send them all at once")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, compact ? 20 : 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(.quaternary.opacity(0.5))
        }
        .contentShape(Rectangle())
        .overlay {
            DragSourceOverlay(
                items: { draggable },
                image: { Thumbnailer.shared.icon(for: $0, size: 64) },
                iconSize: 48,
                onDragEnded: onDragEnded
            )
        }
    }
}
