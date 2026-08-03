//
//  HistoryStore.swift
//  Drake
//
//  Every run that has files is written to ~/Library/Application Support/Drake/
//  history.json so `drake` with no arguments can offer them again.
//

import Foundation
import Observation

struct HistoryEntry: Identifiable, Codable, Hashable {
    enum Kind: String, Codable {
        case source
        case target

        var badge: String {
            switch self {
            case .source: return "source"
            case .target: return "target"
            }
        }
    }

    var id: UUID
    var date: Date
    /// Working directory the run started in; labels are relative to it.
    var directory: String
    var kind: Kind
    var items: [DrakeItem]
    /// Optional user-supplied name, shown instead of the generated summary.
    var title: String?
    var pinned: Bool

    init(
        id: UUID = UUID(),
        date: Date,
        directory: String,
        kind: Kind,
        items: [DrakeItem],
        title: String? = nil,
        pinned: Bool = false
    ) {
        self.id = id
        self.date = date
        self.directory = directory
        self.kind = kind
        self.items = items
        self.title = title
        self.pinned = pinned
    }

    var directoryURL: URL { URL(fileURLWithPath: directory) }

    /// "report.pdf", "report.pdf + 3 more", or the user's title.
    var summary: String {
        if let title, !title.isEmpty { return title }
        guard let first = items.first else { return "Empty" }
        let name = first.fileURL?.lastPathComponent ?? first.uri
        if items.count == 1 { return name }
        return "\(name) + \(items.count - 1) more"
    }

    var directoryLabel: String {
        PathFormatting.abbreviate(directory)
    }

    /// Full, unshortened path for tooltips.
    var directoryTooltip: String {
        (directory as NSString).abbreviatingWithTildeInPath
    }

    var existingItems: [DrakeItem] { items.filter(\.exists) }

    func matches(_ query: String) -> Bool {
        let needle = query.lowercased()
        if summary.lowercased().contains(needle) { return true }
        if directoryLabel.lowercased().contains(needle) { return true }
        return items.contains { $0.raw.lowercased().contains(needle) || $0.uri.lowercased().contains(needle) }
    }
}

@Observable
final class HistoryStore {
    /// Newest first, pinned entries above the rest.
    private(set) var entries: [HistoryEntry] = []
    /// Set when the store cannot be read or written; surfaced in the UI.
    private(set) var errorMessage: String?

    private let fileURL: URL
    private let maximumEntries = 300

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        load()
    }

    static func defaultFileURL() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return support.appendingPathComponent("Drake/history.json")
    }

    // MARK: - Mutation

    /// Records a run, collapsing it into the previous entry when it is a repeat
    /// of the same files from the same directory.
    @discardableResult
    func record(items: [DrakeItem], directory: URL, kind: HistoryEntry.Kind) -> UUID? {
        guard !items.isEmpty || kind == .target else { return nil }

        let signature = Set(items.map(\.uri))
        if let index = entries.firstIndex(where: {
            $0.kind == kind
                && $0.directory == directory.path
                && Set($0.items.map(\.uri)) == signature
                && !signature.isEmpty
        }) {
            entries[index].date = Date()
            sortAndTrim()
            save()
            return entries.first(where: { $0.id == entries[index].id })?.id
        }

        let entry = HistoryEntry(
            date: Date(),
            directory: directory.path,
            kind: kind,
            items: items
        )
        entries.insert(entry, at: 0)
        sortAndTrim()
        save()
        return entry.id
    }

    /// Appends items received in target mode to the entry created for that run.
    func append(items: [DrakeItem], to id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        let known = Set(entries[index].items.map(\.uri))
        let fresh = items.filter { !known.contains($0.uri) }
        guard !fresh.isEmpty else { return }
        entries[index].items.append(contentsOf: fresh)
        entries[index].date = Date()
        sortAndTrim()
        save()
    }

    func delete(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        entries.removeAll { ids.contains($0.id) }
        save()
    }

    func removeItems(_ itemIDs: Set<UUID>, from id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].items.removeAll { itemIDs.contains($0.id) }
        if entries[index].items.isEmpty {
            entries.remove(at: index)
        }
        save()
    }

    func togglePin(id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].pinned.toggle()
        sortAndTrim()
        save()
    }

    func rename(id: UUID, to title: String) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        entries[index].title = trimmed.isEmpty ? nil : trimmed
        save()
    }

    /// Drops everything but pinned entries.
    func clear() {
        entries.removeAll { !$0.pinned }
        save()
    }

    // MARK: - Persistence

    private func sortAndTrim() {
        entries.sort { lhs, rhs in
            if lhs.pinned != rhs.pinned { return lhs.pinned }
            return lhs.date > rhs.date
        }
        guard entries.count > maximumEntries else { return }
        var kept: [HistoryEntry] = []
        var unpinned = 0
        for entry in entries {
            if entry.pinned {
                kept.append(entry)
            } else if unpinned < maximumEntries {
                kept.append(entry)
                unpinned += 1
            }
        }
        entries = kept
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            entries = try decoder.decode([HistoryEntry].self, from: data)
            sortAndTrim()
        } catch {
            errorMessage = "Could not read history: \(error.localizedDescription)"
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(entries).write(to: fileURL, options: .atomic)
            errorMessage = nil
        } catch {
            errorMessage = "Could not save history: \(error.localizedDescription)"
        }
    }
}
