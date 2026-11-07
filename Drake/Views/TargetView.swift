//
//  TargetView.swift
//  Drake
//
//  Target mode: accept drops, print them to standard output, and with --keep
//  turn each one into something you can drag back out.
//

import AppKit
import SwiftUI

struct TargetView: View {
    @Environment(AppModel.self) private var model

    @State private var isHighlighted = false

    private var options: Options { model.options }

    var body: some View {
        VStack(spacing: 0) {
            dropZone
                .padding(Metrics.panelPadding)

            if options.keep && !model.items.isEmpty {
                Divider()
                keptItems
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var dropZone: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)

        return VStack(spacing: 6) {
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(isHighlighted ? AnyShapeStyle(Palette.accent) : AnyShapeStyle(.tertiary))
                .symbolEffect(.bounce, value: isHighlighted)
                .padding(.bottom, 4)
            Text(isHighlighted ? "Release to Drop" : "Drop Here")
                .font(.system(size: 14, weight: .semibold))
            Text(options.printPath ? "Paths are printed to standard output" : "URIs are printed to standard output")
                .font(Typography.detail)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Metrics.dropZoneHeight)
        .background {
            shape.fill(isHighlighted ? Palette.accent.opacity(0.12) : Palette.raised.opacity(0.5))
        }
        .overlay {
            shape.strokeBorder(
                isHighlighted ? Palette.accent : Palette.hairline,
                style: StrokeStyle(lineWidth: isHighlighted ? 1.5 : 1, dash: isHighlighted ? [] : [6, 4])
            )
        }
        .animation(.easeOut(duration: 0.15), value: isHighlighted)
        .overlay {
            DropTargetOverlay(
                onDrop: handle,
                onHighlight: { isHighlighted = $0 }
            )
        }
        .accessibilityElement(children: .combine)
    }

    private var keptItems: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.rowSpacing) {
                ForEach(model.items) { item in
                    ItemRow(
                        item: item,
                        nameStyle: options.nameStyle,
                        baseDirectory: model.baseDirectory,
                        iconSize: Metrics.keptItemIconSize,
                        isSelected: model.selection.contains(item.id),
                        dragItems: { model.dragPayload(startingAt: item) },
                        onClick: { model.click(on: item, modifiers: $0) },
                        onDoubleClick: { model.openSelected() },
                        onDragEnded: { model.dragEnded(accepted: $0) },
                        menu: { menu(for: item) }
                    )
                }
            }
            .padding(.horizontal, Metrics.listPadding)
            .padding(.vertical, Metrics.listPaddingVertical)
        }
    }

    private func handle(_ payload: DroppedPayload) {
        switch payload {
        case .items(let items):
            model.receive(items)
        case .text(let text):
            model.receiveText(text)
        }
    }

    private func menu(for item: DrakeItem) -> NSMenu {
        model.selection.prepareForContextMenu(on: item.id)
        return ContextMenu.make([
            .action("Open") { model.openSelected() },
            .action("Reveal in Finder") { model.revealSelected() },
            .separator,
            .action("Copy Path") { model.copySelectedPaths() },
            .separator,
            .action("Remove from List") { model.removeSelected() },
        ])
    }
}
