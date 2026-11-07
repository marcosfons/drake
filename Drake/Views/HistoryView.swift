//
//  HistoryView.swift
//  Drake
//
//  What `drake` shows with no arguments: every past run, grouped by date,
//  expandable into the items it held, each of them draggable straight out of
//  the list. Search lives in the toolbar; Clear History in the History menu.
//

import AppKit
import SwiftUI

struct HistoryView: View {
    @Environment(AppModel.self) private var model

    @State private var expanded: Set<UUID> = []
    /// One selection per expanded entry, so ⇧-click ranges stay inside an entry.
    @State private var selections: [UUID: Selection] = [:]
    @State private var renaming: UUID?

    private var history: HistoryStore { model.history }

    private var query: String {
        model.historyQuery.trimmingCharacters(in: .whitespaces)
    }

    private var filteredEntries: [HistoryEntry] {
        guard !query.isEmpty else { return history.entries }
        return history.entries.filter { $0.matches(query) }
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .top, spacing: 0) {
                if let error = history.errorMessage {
                    ErrorBanner(message: error)
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if history.entries.isEmpty {
            ContentUnavailableView {
                Label("No History Yet", systemImage: "clock.arrow.circlepath")
            } description: {
                Text("Run `\(Options.programName) file…` and it will show up here.")
            }
        } else if filteredEntries.isEmpty {
            ContentUnavailableView.search(text: query)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(HistorySection.group(filteredEntries)) { section in
                        Section {
                            ForEach(section.entries) { entry in
                                HistoryEntryRow(
                                    entry: entry,
                                    timestamp: HistorySection.timestamp(for: entry.date, in: section.kind),
                                    isExpanded: binding(for: entry.id, in: $expanded),
                                    isRenaming: renamingBinding(for: entry.id),
                                    selection: selectionBinding(for: entry.id)
                                )
                            }
                        } header: {
                            SectionHeader(title: section.kind.title)
                        }
                    }
                }
                .padding(.horizontal, Metrics.listPadding)
                .padding(.bottom, Metrics.listPadding)
            }
        }
    }

    // MARK: - Per-entry state

    private func binding(for id: UUID, in set: Binding<Set<UUID>>) -> Binding<Bool> {
        Binding(
            get: { set.wrappedValue.contains(id) },
            set: { isOn in
                if isOn { set.wrappedValue.insert(id) } else { set.wrappedValue.remove(id) }
            }
        )
    }

    private func renamingBinding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { renaming == id },
            set: { renaming = $0 ? id : nil }
        )
    }

    private func selectionBinding(for id: UUID) -> Binding<Selection> {
        Binding(
            get: { selections[id] ?? Selection() },
            set: { selections[id] = $0 }
        )
    }
}

// MARK: - Entry row

/// One past run: a header that toggles, drags the whole run and opens it on
/// double-click, and, when expanded, its items as ordinary draggable rows.
private struct HistoryEntryRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let entry: HistoryEntry
    let timestamp: String
    @Binding var isExpanded: Bool
    @Binding var isRenaming: Bool
    @Binding var selection: Selection

    @State private var isHeaderHovered = false
    @State private var isButtonHovered = false
    @State private var renameText = ""
    @FocusState private var renameFieldFocused: Bool

    private var history: HistoryStore { model.history }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.rowSpacing) {
            header
            if isExpanded {
                items
                    .transition(.opacity)
            }
        }
    }

    // MARK: Header

    private var header: some View {
        let cache = FileInfoCache.shared
        let firstInfo = entry.items.first.map(cache.info(for:))
        let missing = entry.items.count { !cache.info(for: $0).exists }

        return HStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: 12)

                if let first = entry.items.first, let firstInfo {
                    ItemIcon(item: first, info: firstInfo, size: Metrics.historyIconSize)
                } else {
                    Image(systemName: "tray")
                        .foregroundStyle(.tertiary)
                        .frame(width: Metrics.historyIconSize, height: Metrics.historyIconSize)
                }

                VStack(alignment: .leading, spacing: 2) {
                    if isRenaming {
                        renameField
                    } else {
                        HStack(spacing: 4) {
                            if entry.pinned {
                                Image(systemName: "pin.fill")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(Palette.accent)
                                    .accessibilityLabel("Pinned")
                            }
                            Text(entry.summary)
                                .font(Typography.name)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    Text(entry.subtitle(missingCount: missing))
                        .font(Typography.detail)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 8)

                Text(timestamp)
                    .font(Typography.detail)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(.rect)
            .overlay {
                if !isRenaming {
                    DragSourceOverlay(
                        items: { entry.existingItems },
                        iconSize: 48,
                        toolTip: "\(entry.date.formatted(date: .complete, time: .shortened))\n\(entry.directoryTooltip)",
                        onClick: { _ in toggle() },
                        onDoubleClick: { model.open(entry: entry) },
                        onDragEnded: { model.dragEnded(accepted: $0) },
                        onHover: { isHeaderHovered = $0 },
                        menu: { menu }
                    )
                }
            }

            Button {
                model.open(entry: entry)
            } label: {
                Image(systemName: "arrow.up.forward")
            }
            .buttonStyle(IconButtonStyle())
            .help("Open as Drag Source")
            .accessibilityLabel("Open as Drag Source")
            .onHover { isButtonHovered = $0 }
        }
        .padding(.leading, 6)
        .padding(.trailing, 4)
        .frame(height: Metrics.rowHeight(iconSize: Metrics.historyIconSize))
        .rowBackground(isSelected: false, isHovered: isHeaderHovered || isButtonHovered)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(entry.summary)
        .accessibilityAction(named: isExpanded ? "Collapse" : "Expand") { toggle() }
    }

    private var renameField: some View {
        TextField("Name", text: $renameText)
            .textFieldStyle(.plain)
            .font(Typography.name)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Palette.raised)
                    .strokeBorder(Palette.accent.opacity(0.7))
            }
            .focused($renameFieldFocused)
            .onAppear {
                renameText = entry.title ?? entry.summary
                renameFieldFocused = true
            }
            .onSubmit(commitRename)
            // Clicking elsewhere or pressing Escape ends the edit, like Finder.
            .onChange(of: renameFieldFocused) { _, focused in
                if !focused { commitRename() }
            }
    }

    // MARK: Items

    private var items: some View {
        VStack(alignment: .leading, spacing: Metrics.rowSpacing) {
            ForEach(entry.items) { item in
                ItemRow(
                    item: item,
                    nameStyle: .basename,
                    baseDirectory: entry.directoryURL,
                    iconSize: Metrics.historyItemIconSize,
                    isSelected: selection.contains(item.id),
                    dragItems: { dragPayload(startingAt: item) },
                    onClick: { selection.click(on: item.id, in: entry.items.map(\.id), modifiers: $0) },
                    onDoubleClick: { ItemActions.open([item]) },
                    onDragEnded: { model.dragEnded(accepted: $0) },
                    menu: { menu(for: item) }
                )
            }
        }
        .padding(.leading, 26)
    }

    // MARK: Actions

    private func toggle() {
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) {
            isExpanded.toggle()
        }
    }

    private func commitRename() {
        guard isRenaming else { return }
        history.rename(id: entry.id, to: renameText)
        isRenaming = false
    }

    /// A drag from an item carries the entry's selection when the item is part
    /// of a multiple selection, otherwise just that item.
    private func dragPayload(startingAt item: DrakeItem) -> [DrakeItem] {
        if selection.count > 1, selection.contains(item.id) {
            return entry.items.filter { selection.contains($0.id) && $0.exists }
        }
        return item.exists ? [item] : []
    }

    private var menu: NSMenu {
        ContextMenu.make([
            .action("Open as Drag Source") { model.open(entry: entry) },
            .action(isExpanded ? "Collapse" : "Expand") { toggle() },
            .separator,
            .action("Rename…") { isRenaming = true },
            .action(entry.pinned ? "Unpin" : "Pin") { history.togglePin(id: entry.id) },
            .separator,
            .action("Copy All Paths") { ItemActions.copyPaths(entry.items) },
            .action("Reveal in Finder") { ItemActions.reveal(entry.items) },
            .separator,
            .action("Remove from History") { history.delete(ids: [entry.id]) },
        ])
    }

    private func menu(for item: DrakeItem) -> NSMenu {
        selection.prepareForContextMenu(on: item.id)
        let chosen = entry.items.filter { selection.contains($0.id) }
        let suffix = chosen.count > 1 ? " (\(chosen.count))" : ""

        return ContextMenu.make([
            .action("Open" + suffix) { ItemActions.open(chosen) },
            .action("Reveal in Finder" + suffix) { ItemActions.reveal(chosen) },
            .separator,
            .action("Copy Path" + suffix) { ItemActions.copyPaths(chosen) },
            .separator,
            .action("Remove from Entry" + suffix) {
                history.removeItems(Set(chosen.map(\.id)), from: entry.id)
                selection = Selection()
            },
        ])
    }
}

// MARK: - Pieces

private struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(Typography.sectionHeader)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.top, 12)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.background)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct ErrorBanner: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(Typography.detail)
            .foregroundStyle(.orange)
            .lineLimit(2)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.12))
    }
}
