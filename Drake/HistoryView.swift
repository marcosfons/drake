//
//  HistoryView.swift
//  Drake
//
//  What `drake` shows with no arguments: every past run, expandable into the
//  items it held, each of them draggable straight out of the list.
//

import AppKit
import SwiftUI

struct HistoryView: View {
    @Environment(AppModel.self) private var model

    @State private var query = ""
    @State private var expanded: Set<UUID> = []
    /// One selection per expanded entry, so ⇧-click ranges stay inside an entry.
    @State private var selections: [UUID: Selection] = [:]
    @State private var renamingEntry: UUID?
    @State private var renameText = ""
    @State private var confirmingClear = false

    private var history: HistoryStore { model.history }

    private var entries: [HistoryEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return history.entries }
        return history.entries.filter { $0.matches(trimmed) }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            content
            Divider()
            footer
        }
        .alert("Clear history?", isPresented: $confirmingClear) {
            Button("Clear", role: .destructive) { history.clear() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Pinned entries are kept.")
        }
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search files and folders", text: $query)
                .textFieldStyle(.plain)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - List

    @ViewBuilder
    private var content: some View {
        if history.entries.isEmpty {
            emptyState(
                icon: "clock",
                title: "No history yet",
                message: "Run `\(Options.programName) file…` and it will show up here."
            )
        } else if entries.isEmpty {
            emptyState(icon: "magnifyingglass", title: "No matches", message: "Nothing matches “\(query)”.")
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(entries) { entry in
                        entryCard(entry)
                    }
                }
                .padding(10)
            }
            .background(.background)
        }
    }

    private func entryCard(_ entry: HistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            entryHeader(entry)
            if expanded.contains(entry.id) {
                Divider()
                    .padding(.leading, 34)
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(entry.items) { item in
                        itemRow(item, in: entry)
                    }
                }
                .padding(.vertical, 4)
                .padding(.leading, 20)
                .padding(.trailing, 6)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary.opacity(0.35))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(entry.pinned ? Color.accentColor.opacity(0.5) : .clear)
        }
    }

    private func entryHeader(_ entry: HistoryEntry) -> some View {
        HStack(spacing: 8) {
            // Draggable region: everything but the trailing buttons. Dragging
            // the header sends the whole entry.
            HStack(spacing: 8) {
                Image(systemName: expanded.contains(entry.id) ? "chevron.down" : "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 12)

                if let first = entry.items.first {
                    ItemIcon(item: first, size: 26)
                } else {
                    Image(systemName: "tray")
                        .frame(width: 26, height: 26)
                        .foregroundStyle(.tertiary)
                }

                VStack(alignment: .leading, spacing: 1) {
                    if renamingEntry == entry.id {
                        TextField("Name", text: $renameText)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                history.rename(id: entry.id, to: renameText)
                                renamingEntry = nil
                            }
                    } else {
                        HStack(spacing: 4) {
                            if entry.pinned {
                                Image(systemName: "pin.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.tint)
                            }
                            Text(entry.summary)
                                .fontWeight(.medium)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    Text(subtitle(for: entry))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .help("\(entry.date.formatted(date: .complete, time: .standard))\n\(entry.directoryTooltip)")
            .overlay {
                if renamingEntry != entry.id {
                    DragSourceOverlay(
                        items: { entry.existingItems },
                        image: { Thumbnailer.shared.icon(for: $0, size: 64) },
                        iconSize: 48,
                        onClick: { _ in toggle(entry) },
                        onDoubleClick: { model.open(entry: entry) },
                        onDragEnded: { model.dragEnded(accepted: $0) },
                        menu: { menu(for: entry) }
                    )
                }
            }

            Button {
                model.open(entry: entry)
            } label: {
                Image(systemName: "arrow.up.forward.app")
            }
            .buttonStyle(.borderless)
            .help("Open this run as a drag source")

            Button {
                history.togglePin(id: entry.id)
            } label: {
                Image(systemName: entry.pinned ? "pin.slash" : "pin")
            }
            .buttonStyle(.borderless)
            .help(entry.pinned ? "Unpin" : "Pin to the top")

            Button {
                history.delete(ids: [entry.id])
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Remove from history")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
    }

    private func itemRow(_ item: DrakeItem, in entry: HistoryEntry) -> some View {
        let selection = selections[entry.id] ?? Selection()
        return ItemRow(
            item: item,
            nameStyle: .basename,
            baseDirectory: entry.directoryURL,
            iconSize: 22,
            isSelected: selection.contains(item.id),
            showsDetail: true,
            dragItems: { dragPayload(for: item, in: entry) },
            onClick: { modifiers in
                var updated = selections[entry.id] ?? Selection()
                updated.click(on: item.id, in: entry.items.map(\.id), modifiers: modifiers)
                selections[entry.id] = updated
            },
            onDoubleClick: { open(item) },
            onDragEnded: { model.dragEnded(accepted: $0) },
            menu: { menu(for: item, in: entry) }
        )
    }

    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 8) {
            if model.canReturnFromHistory {
                Button {
                    model.returnFromHistory()
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .help("Back to the files this run opened with (⌘[)")
                .keyboardShortcut("[", modifiers: .command)
            }

            Text("\(history.entries.count) run\(history.entries.count == 1 ? "" : "s") remembered")
                .font(.callout)
                .foregroundStyle(.secondary)

            if let error = history.errorMessage {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .help(error)
            }

            Spacer()

            Button("Clear…") { confirmingClear = true }
                .disabled(history.entries.allSatisfy(\.pinned))

            Button("Close") { model.terminate() }
                .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, 12)
        .frame(height: Metrics.footerHeight)
        .background(.bar)
    }

    // MARK: - Helpers

    private func subtitle(for entry: HistoryEntry) -> String {
        let count = entry.items.count
        let missing = count - entry.existingItems.count
        var parts = ["\(count) item\(count == 1 ? "" : "s")"]
        if missing > 0 { parts.append("\(missing) missing") }
        parts.append(entry.date.formatted(.relative(presentation: .named)))
        parts.append(entry.directoryLabel)
        if entry.kind == .target { parts.insert("dropped in", at: 0) }
        return parts.joined(separator: " · ")
    }

    private func toggle(_ entry: HistoryEntry) {
        if expanded.contains(entry.id) {
            expanded.remove(entry.id)
        } else {
            expanded.insert(entry.id)
        }
    }

    /// A drag from an item carries the entry's selection when the item is part
    /// of a multiple selection, otherwise just that item.
    private func dragPayload(for item: DrakeItem, in entry: HistoryEntry) -> [DrakeItem] {
        let selection = selections[entry.id] ?? Selection()
        if selection.count > 1, selection.contains(item.id) {
            return entry.items.filter { selection.contains($0.id) && $0.exists }
        }
        return item.exists ? [item] : []
    }

    private func open(_ item: DrakeItem) {
        if let url = item.fileURL {
            NSWorkspace.shared.open(url)
        } else if let url = URL(string: item.uri) {
            NSWorkspace.shared.open(url)
        }
    }

    private func menu(for entry: HistoryEntry) -> NSMenu {
        ContextMenuBuilder.make([
            ("Open as Drag Source", { model.open(entry: entry) }),
            (expanded.contains(entry.id) ? "Collapse" : "Expand", { toggle(entry) }),
            nil,
            ("Rename…", {
                renameText = entry.title ?? entry.summary
                renamingEntry = entry.id
            }),
            (entry.pinned ? "Unpin" : "Pin", { history.togglePin(id: entry.id) }),
            nil,
            ("Copy All Paths", {
                let text = entry.items.map(\.dragText).joined(separator: "\n")
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            }),
            ("Reveal in Finder", {
                let urls = entry.existingItems.compactMap(\.fileURL)
                if !urls.isEmpty { NSWorkspace.shared.activateFileViewerSelecting(urls) }
            }),
            nil,
            ("Remove from History", { history.delete(ids: [entry.id]) }),
        ])
    }

    private func menu(for item: DrakeItem, in entry: HistoryEntry) -> NSMenu {
        var selection = selections[entry.id] ?? Selection()
        selection.prepareForContextMenu(on: item.id)
        selections[entry.id] = selection
        let chosen = entry.items.filter { selection.contains($0.id) }
        let suffix = chosen.count > 1 ? " (\(chosen.count))" : ""

        return ContextMenuBuilder.make([
            ("Open" + suffix, { chosen.forEach(open) }),
            ("Reveal in Finder" + suffix, {
                let urls = chosen.compactMap(\.fileURL).filter { FileManager.default.fileExists(atPath: $0.path) }
                if !urls.isEmpty { NSWorkspace.shared.activateFileViewerSelecting(urls) }
            }),
            nil,
            ("Copy Path" + suffix, {
                let text = chosen.map(\.dragText).joined(separator: "\n")
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            }),
            nil,
            ("Remove from Entry" + suffix, {
                history.removeItems(Set(chosen.map(\.id)), from: entry.id)
                selections[entry.id] = Selection()
            }),
        ])
    }
}
