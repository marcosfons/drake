//
//  SourceView.swift
//  Drake
//
//  Drag source: the files given on the command line, or a history entry.
//

import AppKit
import SwiftUI

struct SourceView: View {
    @Environment(AppModel.self) private var model

    /// Scroll position, so sweep-selection can map points to rows.
    @State private var scrollOffset: CGFloat = 0
    /// Selection a sweep started from, for ⌘/⇧ sweeps that add to it.
    @State private var sweepBase: Set<UUID> = []

    private var options: Options { model.options }

    var body: some View {
        VStack(spacing: 0) {
            content
            Divider()
            footer
        }
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
        .onChange(of: model.items) { _, _ in
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
                .padding(12)
        } else {
            VStack(spacing: Metrics.dragAllTileSpacing) {
                // Kept out of the scroll view so it stays reachable.
                if options.dragAll {
                    DragAllTile(items: model.items, compact: false) { model.dragEnded(accepted: $0) }
                        .frame(height: Metrics.dragAllTileHeight)
                        .padding(.horizontal, Metrics.listPadding)
                        .padding(.top, Metrics.listPadding)
                }

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
                // Exactly as tall as its rows on opening, and free to grow into
                // whatever height the window is resized to.
                .frame(minHeight: listHeight, maxHeight: .infinity)
                .background(.background)
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    geometry.contentOffset.y
                } action: { _, offset in
                    scrollOffset = offset
                }
                .overlay {
                    // Sweep-select from any empty space. Presses that land on a
                    // row fall through to the row and start a drag instead.
                    if !options.iconOnly {
                        MarqueeSelectionOverlay(
                            rowCount: model.items.count,
                            rowHeight: Metrics.rowHeight(iconSize: rowIconSize),
                            scrollOffset: scrollOffset,
                            onBegin: { additive in
                                sweepBase = additive ? model.selection.ids : []
                                if !additive { model.clearSelection() }
                            },
                            onSweep: { indices, _ in
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
        }
    }

    /// Height the list is given: fits the rows, capped at `maxVisibleRows`.
    private var listHeight: CGFloat {
        if options.iconOnly {
            let rows = Metrics.gridRows(
                count: model.items.count,
                iconSize: options.thumbSize,
                width: Metrics.sourceWidth
            )
            return Metrics.visibleListHeight(rowCount: min(rows, 4), iconSize: options.thumbSize)
        }
        return Metrics.visibleListHeight(rowCount: model.items.count, iconSize: rowIconSize)
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
                onDoubleClick: {
                    model.selection.prepareForContextMenu(on: item.id)
                    model.openSelected()
                },
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
                    baseDirectory: model.baseDirectory,
                    iconSize: options.thumbSize,
                    isSelected: model.selection.contains(item.id),
                    dragItems: { model.dragPayload(startingAt: item) },
                    onClick: { model.click(on: item, modifiers: $0) },
                    onDoubleClick: {
                        model.selection.prepareForContextMenu(on: item.id)
                        model.openSelected()
                    },
                    onDragEnded: { model.dragEnded(accepted: $0) },
                    menu: { contextMenu(for: item) }
                )
            }
        }
    }

    /// Rows stay compact; `--thumb-size` only blows up the icon-only grid, as in dragon.
    private var rowIconSize: CGFloat {
        min(max(options.thumbSize / 3, 24), 64)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("Nothing to drag")
                .foregroundStyle(.secondary)
            if model.canGoBackToHistory {
                Button("Browse History") { model.showHistory() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 8) {
            Text(statusText)
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer()

            if model.canGoBackToHistory {
                Button {
                    model.showHistory()
                } label: {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .help("Show previous runs (⌘Y)")
            }

            Button("Close") { model.terminate() }
                .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, 12)
        .frame(height: Metrics.footerHeight)
        .background(.bar)
    }

    private var statusText: String {
        let total = model.items.count
        let selected = model.selection.count
        var text = "\(total) item\(total == 1 ? "" : "s")"
        if selected > 0 { text += " - \(selected) selected" }
        if options.dragAll { text += " - dragging all at once" }
        return text
    }

    // MARK: - Context menu

    private func contextMenu(for item: DrakeItem) -> NSMenu {
        model.selection.prepareForContextMenu(on: item.id)
        let count = model.selection.count
        let suffix = count > 1 ? " (\(count))" : ""
        return ContextMenuBuilder.make([
            ("Open" + suffix, { model.openSelected() }),
            ("Reveal in Finder" + suffix, { model.revealSelected() }),
            nil,
            ("Copy Path" + suffix, { model.copySelectedPaths() }),
            nil,
            ("Remove from List" + suffix, { model.removeSelected() }),
        ])
    }
}
