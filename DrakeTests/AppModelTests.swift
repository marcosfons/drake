//
//  AppModelTests.swift
//  DrakeTests
//

import AppKit
import Foundation
import Testing

@testable import Drake

@MainActor
struct AppModelTests {
    private func makeSandbox() throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("DrakeModel-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for name in ["a.txt", "b.txt", "c.txt"] {
            try Data("x".utf8).write(to: directory.appendingPathComponent(name))
        }
        return directory
    }

    /// Builds a model as if the process had been launched from `directory`.
    private func makeModel(_ argv: [String], in directory: URL) throws -> AppModel {
        var options = try Options.parse(argv)
        options.recordHistory = false
        let store = HistoryStore(
            fileURL: directory.appendingPathComponent("history-\(UUID().uuidString).json")
        )
        let previous = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(directory.path)
        defer { FileManager.default.changeCurrentDirectoryPath(previous) }
        return try AppModel(options: options, history: store)
    }

    @Test func missingFileIsRejectedLikeDragon() throws {
        let directory = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: directory) }
        #expect(throws: AppModelError.self) {
            try makeModel(["nope.txt"], in: directory)
        }
    }

    @Test func modeFollowsOptions() throws {
        let directory = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: directory) }

        #expect(try makeModel(["a.txt"], in: directory).mode == .source)
        #expect(try makeModel(["--target"], in: directory).mode == .target)
        #expect(try makeModel([], in: directory).mode == .history)
        #expect(try makeModel(["--history", "a.txt"], in: directory).mode == .history)
    }

    @Test func dragPayloadUsesWholeSelection() throws {
        let directory = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: directory) }

        let model = try makeModel(["a.txt", "b.txt", "c.txt"], in: directory)
        let items = model.items

        // Everything starts selected, so one drag carries the whole list.
        #expect(model.selection.count == 3)
        #expect(model.dragPayload(startingAt: items[0]).count == 3)

        // Clicking one row narrows it to that row.
        model.click(on: items[0], modifiers: [])
        #expect(model.dragPayload(startingAt: items[0]).count == 1)

        model.click(on: items[0], modifiers: [])
        model.click(on: items[2], modifiers: .shift)
        #expect(model.selection.count == 3)
        #expect(model.dragPayload(startingAt: items[1]).count == 3)

        // A row outside the selection drags on its own.
        model.selection.clear()
        model.click(on: items[0], modifiers: [])
        model.click(on: items[1], modifiers: .command)
        #expect(model.dragPayload(startingAt: items[2]).map(\.id) == [items[2].id])
    }

    @Test func dragAllIgnoresSelection() throws {
        let directory = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: directory) }

        let model = try makeModel(["--all", "a.txt", "b.txt"], in: directory)
        model.click(on: model.items[0], modifiers: [])
        #expect(model.dragPayload(startingAt: model.items[0]).count == 2)
    }

    @Test func targetModeKeepsAndDeduplicatesReceivedItems() throws {
        let directory = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: directory) }

        let model = try makeModel(["--target", "--keep"], in: directory)
        let dropped = DrakeItem.file(at: directory.appendingPathComponent("a.txt"))
        model.receive([dropped])
        model.receive([dropped])
        #expect(model.receivedCount == 2)
        #expect(model.items.count == 1)
    }

    @Test func targetModeWithoutKeepShowsNothing() throws {
        let directory = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: directory) }

        let model = try makeModel(["--target"], in: directory)
        model.receive([DrakeItem.file(at: directory.appendingPathComponent("a.txt"))])
        #expect(model.receivedCount == 1)
        #expect(model.items.isEmpty)
    }

    @Test func openingHistoryEntrySwitchesToSource() throws {
        let directory = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: directory) }

        let model = try makeModel([], in: directory)
        #expect(model.mode == .history)

        let entry = HistoryEntry(
            date: Date(),
            directory: directory.path,
            kind: .source,
            items: [DrakeItem.file(at: directory.appendingPathComponent("a.txt"))]
        )
        model.open(entry: entry)
        #expect(model.mode == .source)
        #expect(model.items.count == 1)
        #expect(model.windowTitle.contains("a.txt"))

        model.showHistory()
        #expect(model.mode == .history)
    }

    @Test func historyRemembersTheScreenItWasOpenedFrom() throws {
        let directory = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: directory) }

        let model = try makeModel(["a.txt", "b.txt"], in: directory)
        #expect(model.mode == .source)
        #expect(!model.canReturnFromHistory)

        model.showHistory()
        #expect(model.mode == .history)
        #expect(model.canReturnFromHistory)

        model.returnFromHistory()
        #expect(model.mode == .source)
        #expect(model.items.count == 2)
        #expect(model.selection.count == 2)
        #expect(!model.canReturnFromHistory)
    }

    @Test func historyOpenedWithNoFilesHasNowhereToGoBackTo() throws {
        let directory = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: directory) }

        let model = try makeModel([], in: directory)
        #expect(model.mode == .history)
        #expect(!model.canReturnFromHistory)
    }

    @Test func historyFlagWithFilesCanGoBackToThem() throws {
        let directory = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: directory) }

        let model = try makeModel(["--history", "a.txt"], in: directory)
        #expect(model.mode == .history)
        #expect(model.canReturnFromHistory)

        model.returnFromHistory()
        #expect(model.mode == .source)
        #expect(model.items.count == 1)
    }

    @Test func openingAnEntryReplacesTheScreenToGoBackTo() throws {
        let directory = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: directory) }

        let model = try makeModel(["a.txt"], in: directory)
        model.showHistory()
        model.open(entry: HistoryEntry(
            date: Date(),
            directory: directory.path,
            kind: .source,
            items: [DrakeItem.file(at: directory.appendingPathComponent("b.txt"))]
        ))
        #expect(model.mode == .source)
        #expect(!model.canReturnFromHistory, "opening an entry navigates forward")

        // From there, History and Back still work.
        model.showHistory()
        #expect(model.canReturnFromHistory)
        model.returnFromHistory()
        #expect(model.items.first?.fileURL?.lastPathComponent == "b.txt")
    }

    @Test func targetModeReturnsToTargetNotSource() throws {
        let directory = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: directory) }

        let model = try makeModel(["--target"], in: directory)
        model.showHistory()
        model.returnFromHistory()
        #expect(model.mode == .target)
    }

    @Test func missingFilesAreNotDragged() throws {
        let directory = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: directory) }

        let model = try makeModel([], in: directory)
        let gone = DrakeItem.file(at: directory.appendingPathComponent("vanished.txt"))
        model.items = [gone]
        #expect(model.dragPayload(startingAt: gone).isEmpty)
    }

    @Test func windowTitleSaysWhatIsListedAndSelected() throws {
        let directory = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: directory) }

        let model = try makeModel(["a.txt", "b.txt", "c.txt"], in: directory)
        #expect(model.windowTitle == "3 Items", "everything starts selected")
        model.click(on: model.items[0], modifiers: [])
        model.click(on: model.items[1], modifiers: .command)
        #expect(model.windowTitle == "2 of 3 Selected")
        model.clearSelection()
        #expect(model.windowTitle == "3 Items")

        let single = try makeModel(["a.txt"], in: directory)
        #expect(single.windowTitle == "1 Item")

        let all = try makeModel(["-a", "a.txt", "b.txt"], in: directory)
        all.click(on: all.items[0], modifiers: [])
        #expect(all.windowTitle == "2 Items", "--all drags everything, whatever is selected")
    }

    @Test func windowTitleForTargetAndHistory() throws {
        let directory = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: directory) }

        let target = try makeModel(["-t"], in: directory)
        #expect(target.windowTitle == "Drop Target")
        target.receive([.uri("https://example.com")])
        #expect(target.windowTitle == "1 Received")

        let history = try makeModel([], in: directory)
        #expect(history.windowTitle == "History")
    }

    @Test func leavingHistoryClearsTheSearch() throws {
        let directory = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: directory) }

        let model = try makeModel(["a.txt"], in: directory)
        model.showHistory()
        model.historyQuery = "report"
        model.returnFromHistory()
        #expect(model.historyQuery.isEmpty)
    }
}
