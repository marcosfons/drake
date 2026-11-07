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
                .padding(12)

            if options.keep && !model.items.isEmpty {
                Divider()
                keptItems
            }

            Divider()
            footer
        }
    }

    private var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(isHighlighted ? AnyShapeStyle(Palette.accent.opacity(0.14)) : AnyShapeStyle(.quaternary.opacity(0.35)))
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isHighlighted ? Palette.accent : Color.secondary.opacity(0.45),
                    style: StrokeStyle(lineWidth: isHighlighted ? 2 : 1.5, dash: [7, 5])
                )

            VStack(spacing: 8) {
                Image(systemName: isHighlighted ? "arrow.down.circle.fill" : "arrow.down.circle")
                    .font(.system(size: 34))
                    .foregroundStyle(isHighlighted ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                Text("Drag something here…")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(options.printPath ? "Paths are printed to standard output" : "URIs are printed to standard output")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(minHeight: 140)
        .animation(.easeOut(duration: 0.12), value: isHighlighted)
        .overlay {
            DropTargetOverlay(
                onDrop: handle,
                onHighlight: { isHighlighted = $0 }
            )
        }
    }

    private var keptItems: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(model.items) { item in
                    ItemRow(
                        item: item,
                        nameStyle: options.nameStyle,
                        baseDirectory: model.baseDirectory,
                        iconSize: 28,
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
        .frame(height: Metrics.visibleListHeight(rowCount: model.items.count, iconSize: 28))
        .background(Palette.background)
    }

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
                .help("Close (Escape or q)")
        }
        .buttonStyle(FooterButtonStyle())
        .padding(.horizontal, 8)
        .padding(.leading, 4)
        .frame(height: Metrics.footerHeight)
        .background(Palette.bar)
    }

    private var statusText: String {
        if model.receivedCount == 0 { return "Waiting for a drop" }
        return "\(model.receivedCount) item\(model.receivedCount == 1 ? "" : "s") received"
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
        return ContextMenuBuilder.make([
            ("Open", { model.openSelected() }),
            ("Reveal in Finder", { model.revealSelected() }),
            nil,
            ("Copy Path", { model.copySelectedPaths() }),
            nil,
            ("Remove from List", { model.removeSelected() }),
        ])
    }
}
