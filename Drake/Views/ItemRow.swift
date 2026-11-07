//
//  ItemRow.swift
//  Drake
//
//  One draggable row, shared by the source list, kept drops and expanded
//  history entries. Plus the icon-only tile and the drag-everything tile.
//

import AppKit
import SwiftUI

struct ItemRow: View {
    let item: DrakeItem
    var nameStyle: NameStyle = .relative
    let baseDirectory: URL
    let iconSize: CGFloat
    var isSelected = false

    /// What a drag starting here carries - usually the whole selection.
    let dragItems: () -> [DrakeItem]
    let onClick: (NSEvent.ModifierFlags) -> Void
    var onDoubleClick: () -> Void = {}
    var onDragEnded: (Bool) -> Void = { _ in }
    var menu: () -> NSMenu? = { nil }

    @State private var isHovered = false

    var body: some View {
        let info = FileInfoCache.shared.info(for: item)
        let detail = item.detail(info, relativeTo: baseDirectory)

        HStack(spacing: 10) {
            ItemIcon(item: item, info: info, size: iconSize)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(item.label(style: nameStyle, relativeTo: baseDirectory))
                        .font(Typography.name)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if !info.exists {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                            .accessibilityLabel("Missing")
                    }
                }
                if !detail.isEmpty {
                    Text(detail)
                        .font(Typography.detail)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer(minLength: 0)

            // Always laid out, so selecting a row never shifts its text.
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.accent)
                .opacity(isSelected ? 1 : 0)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 8)
        .frame(height: Metrics.rowHeight(iconSize: iconSize))
        .frame(maxWidth: .infinity, alignment: .leading)
        .rowBackground(isSelected: isSelected, isHovered: isHovered)
        .contentShape(.rect)
        .overlay {
            DragSourceOverlay(
                items: dragItems,
                iconSize: max(iconSize, 40),
                toolTip: item.dragText,
                onClick: onClick,
                onDoubleClick: onDoubleClick,
                onDragEnded: onDragEnded,
                onHover: { isHovered = $0 },
                menu: menu
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Icon-only tile for `--icon-only`.
struct ItemTile: View {
    let item: DrakeItem
    let iconSize: CGFloat
    let isSelected: Bool

    let dragItems: () -> [DrakeItem]
    let onClick: (NSEvent.ModifierFlags) -> Void
    var onDoubleClick: () -> Void = {}
    var onDragEnded: (Bool) -> Void = { _ in }
    var menu: () -> NSMenu? = { nil }

    @State private var isHovered = false

    var body: some View {
        let info = FileInfoCache.shared.info(for: item)

        ItemIcon(item: item, info: info, size: iconSize)
            .padding(6)
            .rowBackground(isSelected: isSelected, isHovered: isHovered, cornerRadius: 10)
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white, Palette.accent)
                        .padding(3)
                }
            }
            .contentShape(.rect)
            .overlay {
                DragSourceOverlay(
                    items: dragItems,
                    image: { Thumbnailer.shared.image(for: $0, size: iconSize) },
                    iconSize: iconSize,
                    toolTip: item.dragText,
                    onClick: onClick,
                    onDoubleClick: onDoubleClick,
                    onDragEnded: onDragEnded,
                    onHover: { isHovered = $0 },
                    menu: menu
                )
            }
            .accessibilityElement()
            .accessibilityLabel(item.fileURL?.lastPathComponent ?? item.uri)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// The "drag everything at once" control used by `--all` and `--all-compact`.
struct DragAllTile: View {
    let items: [DrakeItem]
    let compact: Bool
    var onDragEnded: (Bool) -> Void = { _ in }

    @State private var isHovered = false

    var body: some View {
        let count = items.count { FileInfoCache.shared.info(for: $0).exists }

        HStack(spacing: 12) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: compact ? 26 : 18, weight: .medium))
                .foregroundStyle(Palette.accent)
                .frame(width: compact ? 36 : 26)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(count) \(count == 1 ? "Item" : "Items")")
                    .font(compact ? .system(size: 15, weight: .semibold) : Typography.name)
                Text("Drag from here to send them all at once")
                    .font(Typography.detail)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isHovered ? Palette.raised.opacity(1.6) : Palette.raised)
                .strokeBorder(Palette.hairline)
        }
        .contentShape(.rect)
        .overlay {
            DragSourceOverlay(
                items: { items.filter(\.exists) },
                iconSize: 48,
                onDragEnded: onDragEnded,
                onHover: { isHovered = $0 }
            )
        }
        .accessibilityElement(children: .combine)
    }
}
