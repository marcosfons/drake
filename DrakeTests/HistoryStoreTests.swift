//
//  HistoryStoreTests.swift
//  DrakeTests
//

import AppKit
import Foundation
import Testing

@testable import Drake

@MainActor
struct HistoryStoreTests {
    private func makeStore() -> (HistoryStore, URL) {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("DrakeTests-\(UUID().uuidString)")
        return (HistoryStore(fileURL: directory.appendingPathComponent("history.json")), directory)
    }

    private func item(_ name: String) -> DrakeItem {
        DrakeItem.fromArgument("/tmp/\(name)", relativeTo: URL(fileURLWithPath: "/tmp"))
    }

    @Test func recordsAndReloadsFromDisk() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        store.record(items: [item("a.txt"), item("b.txt")], directory: URL(fileURLWithPath: "/tmp"), kind: .source)
        #expect(store.entries.count == 1)
        #expect(store.entries[0].items.count == 2)
        #expect(store.errorMessage == nil)

        let reloaded = HistoryStore(fileURL: directory.appendingPathComponent("history.json"))
        #expect(reloaded.entries.count == 1)
        #expect(reloaded.entries[0].items.map(\.uri) == store.entries[0].items.map(\.uri))
    }

    @Test func repeatedRunCollapsesIntoOneEntry() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let items = [item("a.txt")]
        store.record(items: items, directory: URL(fileURLWithPath: "/tmp"), kind: .source)
        store.record(items: items, directory: URL(fileURLWithPath: "/tmp"), kind: .source)
        #expect(store.entries.count == 1)

        store.record(items: items, directory: URL(fileURLWithPath: "/var"), kind: .source)
        #expect(store.entries.count == 2)
    }

    @Test func targetRunAppendsReceivedItems() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let id = try #require(store.record(items: [], directory: URL(fileURLWithPath: "/tmp"), kind: .target))
        store.append(items: [item("a.txt")], to: id)
        store.append(items: [item("a.txt"), item("b.txt")], to: id)
        #expect(store.entries.count == 1)
        #expect(store.entries[0].items.count == 2)
    }

    @Test func pinnedEntriesSortFirstAndSurviveClear() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        store.record(items: [item("old.txt")], directory: URL(fileURLWithPath: "/tmp"), kind: .source)
        let oldID = store.entries[0].id
        store.record(items: [item("new.txt")], directory: URL(fileURLWithPath: "/tmp"), kind: .source)
        #expect(store.entries.first?.items.first?.uri.hasSuffix("new.txt") == true)

        store.togglePin(id: oldID)
        #expect(store.entries.first?.id == oldID)

        store.clear()
        #expect(store.entries.map(\.id) == [oldID])
    }

    @Test func removingEveryItemRemovesTheEntry() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        store.record(items: [item("a.txt"), item("b.txt")], directory: URL(fileURLWithPath: "/tmp"), kind: .source)
        let entry = store.entries[0]
        store.removeItems([entry.items[0].id], from: entry.id)
        #expect(store.entries[0].items.count == 1)
        store.removeItems([store.entries[0].items[0].id], from: entry.id)
        #expect(store.entries.isEmpty)
    }

    @Test func searchMatchesNamesAndDirectories() throws {
        let entry = HistoryEntry(
            date: Date(),
            directory: "/Users/someone/reports",
            kind: .source,
            items: [item("quarterly.pdf")]
        )
        #expect(entry.matches("quarter"))
        #expect(entry.matches("REPORTS"))
        #expect(!entry.matches("nothing-like-this"))
    }

    @Test func summaryDescribesTheRun() {
        let one = HistoryEntry(date: Date(), directory: "/tmp", kind: .source, items: [item("a.txt")])
        #expect(one.summary == "a.txt")

        let many = HistoryEntry(
            date: Date(),
            directory: "/tmp",
            kind: .source,
            items: [item("a.txt"), item("b.txt"), item("c.txt")]
        )
        #expect(many.summary == "a.txt + 2 more")

        var named = many
        named.title = "Invoices"
        #expect(named.summary == "Invoices")
    }
}

@MainActor
struct HistoryStoreOrderingTests {
    @Test func repeatedRunReturnsItsOwnEntryAfterResorting() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("DrakeTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = HistoryStore(fileURL: directory.appendingPathComponent("history.json"))
        let base = URL(fileURLWithPath: "/tmp")
        let a = [DrakeItem.fromArgument("/tmp/a.txt", relativeTo: base)]
        let b = [DrakeItem.fromArgument("/tmp/b.txt", relativeTo: base)]

        let first = store.record(items: a, directory: base, kind: .source)
        _ = store.record(items: b, directory: base, kind: .source)
        // Repeating the older run moves it back to the top.
        let repeated = store.record(items: a, directory: base, kind: .source)
        #expect(repeated == first)
        #expect(store.entries.first?.id == first)
    }

    @Test func subtitleCountsItemsMissingFilesAndFolder() {
        let base = URL(fileURLWithPath: "/tmp")
        let items = ["a", "b"].map { DrakeItem.fromArgument("/tmp/\($0)", relativeTo: base) }
        let source = HistoryEntry(date: .now, directory: "/tmp", kind: .source, items: items)
        #expect(source.subtitle(missingCount: 0) == "2 items - /tmp")
        #expect(source.subtitle(missingCount: 1) == "2 items - 1 missing - /tmp")

        let target = HistoryEntry(date: .now, directory: "/tmp", kind: .target, items: items)
        #expect(target.subtitle(missingCount: 0) == "2 dropped - /tmp")
    }
}

struct HistorySectionTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private let now = Date(timeIntervalSince1970: 1_800_000_000)  // mid-day UTC

    private func entry(daysAgo: Double, pinned: Bool = false) -> HistoryEntry {
        HistoryEntry(
            date: now.addingTimeInterval(-daysAgo * 86_400),
            directory: "/tmp",
            kind: .source,
            items: [],
            pinned: pinned
        )
    }

    @Test func groupsByDateWithPinnedFirst() {
        let entries = [
            entry(daysAgo: 0, pinned: true),
            entry(daysAgo: 0),
            entry(daysAgo: 1),
            entry(daysAgo: 3),
            entry(daysAgo: 30),
        ]
        let sections = HistorySection.group(entries, now: now, calendar: calendar)
        #expect(sections.map(\.kind) == [.pinned, .today, .yesterday, .previousWeek, .earlier])
        #expect(sections.allSatisfy { $0.entries.count == 1 })
    }

    @Test func emptySectionsAreLeftOut() {
        let sections = HistorySection.group([entry(daysAgo: 0), entry(daysAgo: 0.1)], now: now, calendar: calendar)
        #expect(sections.map(\.kind) == [.today])
        #expect(sections.first?.entries.count == 2)
    }

    @Test func keepsTheOrderItWasGiven() {
        let newer = entry(daysAgo: 2)
        let older = entry(daysAgo: 4)
        let sections = HistorySection.group([newer, older], now: now, calendar: calendar)
        #expect(sections.first?.entries.map(\.id) == [newer.id, older.id])
    }
}
