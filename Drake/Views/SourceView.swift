//
//  SourceView.swift
//  Drake
//
//  Drag source: the files given on the command line, or a history entry.
//  No footer: the window title carries the count, the toolbar carries History,
//  and Escape, q or ⌘W close the window.
//

import AppKit
import SwiftUI

struct SourceView: View {
    @Environment(AppModel.self) private var model

    /// Scroll position, so sweep-selection can map points to rows.
    @State private var scrollOffset = ScrollOffsetBox()
    /// Selection a sweep started from, for ⌘/⇧ sweeps that add to it.
    @State private var sweepBase: Set<UUID> = []

    private var options: Options { model.options }
    private var rowIconSize: CGFloat { Metrics.rowIconSize(thumbSize: options.thumbSize) }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .focusable()
            .focusEffectDisabled()
            .onKeyPress(keys: [.upArrow, .downArrow]) { press in
                model.moveSelection(
                    by: press.key == .downArrow ? 1 : -1,
                    extending: press.modifiers.contains(.shift)
                )
                return .handled
            }
            .onKeyPress(.return) {
                model.openSelected()
                return .handled
            }
            .onChange(of: model.items) {
                model.selection.prune(to: model.itemOrder)
            }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if model.items.isEmpty {
            emptyState
        } else if options.allCompact {
            DragAllTile(items: model.items, compact: true) { model.dragEnded(accepted: $0) }
                .padding(Metrics.panelPadding)
        } else {
            VStack(spacing: Metrics.dragAllTileSpacing) {
                // Kept out of the scroll view so it stays reachable.
                if options.dragAll {
                    DragAllTile(items: model.items, compact: false) { model.dragEnded(accepted: $0) }
                        .frame(height: Metrics.dragAllTileHeight)
                        .padding(.horizontal, Metrics.listPadding)
                        .padding(.top, Metrics.listPadding)
                }
                list
            }
        }
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.rowSpacing) {
                if options.iconOnly {
                    iconGrid
                } else {
                    rows
                }
            }
            .padding(.horizontal, Metrics.listPadding)
            .padding(.vertical, Metrics.listPaddingVertical)
        }
        .scrollIndicators(.automatic)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y
        } action: { _, offset in
            scrollOffset.value = offset
        }
        .overlay {
            // Sweep-select from any empty space. Presses that land on a row
            // fall through to the row and start a drag instead.
            if !options.iconOnly {
                MarqueeSelectionOverlay(
                    rowCount: model.items.count,
                    rowHeight: Metrics.rowHeight(iconSize: rowIconSize),
                    scrollOffset: scrollOffset,
                    onBegin: { additive in
                        sweepBase = additive ? model.selection.ids : []
                        if !additive { model.clearSelection() }
                    },
                    onSweep: { indices in
                        let swept = indices.compactMap { index in
                            index < model.items.count ? model.items[index].id : nil
                        }
                        model.selection.ids = sweepBase.union(swept)
                        model.selection.anchor = swept.last ?? model.selection.anchor
                    }
                )
            }
        }
    }

    private var rows: some View {
        ForEach(model.items) { item in
            ItemRow(
                item: item,
                nameStyle: options.nameStyle,
                baseDirectory: model.baseDirectory,
                iconSize: rowIconSize,
                isSelected: model.selection.contains(item.id),
                dragItems: { model.dragPayload(startingAt: item) },
                onClick: { model.click(on: item, modifiers: $0) },
                onDoubleClick: { open(item) },
                onDragEnded: { model.dragEnded(accepted: $0) },
                menu: { contextMenu(for: item) }
            )
        }
    }

    private var iconGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: options.thumbSize + 16), spacing: 8)],
            spacing: 8
        ) {
            ForEach(model.items) { item in
                ItemTile(
                    item: item,
                    iconSize: options.thumbSize,
                    isSelected: model.selection.contains(item.id),
                    dragItems: { model.dragPayload(startingAt: item) },
                    onClick: { model.click(on: item, modifiers: $0) },
                    onDoubleClick: { open(item) },
                    onDragEnded: { model.dragEnded(accepted: $0) },
                    menu: { contextMenu(for: item) }
                )
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Nothing to Drag", systemImage: "tray")
        } description: {
            Text("Every item was removed from the list.")
        } actions: {
            if model.canGoBackToHistory {
                Button("Browse History") { model.showHistory() }
            }
        }
    }

    // MARK: - Actions

    /// Double-click opens the item, along with the rest of the selection when
    /// it is part of it.
    private func open(_ item: DrakeItem) {
        model.selection.prepareForContextMenu(on: item.id)
        model.openSelected()
    }

    private func contextMenu(for item: DrakeItem) -> NSMenu {
        model.selection.prepareForContextMenu(on: item.id)
        let count = model.selection.count
        let suffix = count > 1 ? " (\(count))" : ""
        return ContextMenu.make([
            .action("Open" + suffix) { model.openSelected() },
            .action("Reveal in Finder" + suffix) { model.revealSelected() },
            .separator,
            .action("Copy Path" + suffix) { model.copySelectedPaths() },
            .separator,
            .action("Remove from List" + suffix) { model.removeSelected() },
        ])
    }
}
