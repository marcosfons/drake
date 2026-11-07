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
                            .foregroundStyle(.orange)
                            .help("This file no longer exists")
                    }
                }
                let detail = item.detail(relativeTo: baseDirectory)
                if showsDetail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer(minLength: 0)

            // Always laid out, so selecting a row never shifts its text.
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(Palette.accent)
                .opacity(isSelected ? 1 : 0)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 8)
        .frame(height: Metrics.rowHeight(iconSize: iconSize))
        .frame(maxWidth: .infinity, alignment: .leading)
        .selectionBackground(isSelected, cornerRadius: 6)
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
            .selectionBackground(isSelected, cornerRadius: 8)
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.white, Palette.accent)
                        .padding(2)
                }
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
