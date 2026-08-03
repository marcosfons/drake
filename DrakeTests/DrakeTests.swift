//
//  DrakeTests.swift
//  DrakeTests
//

import AppKit
import Foundation
import Testing

@testable import Drake

// MARK: - Option parsing

struct OptionParsingTests {
    @Test func defaultsToHistoryWithNoArguments() throws {
        let options = try Options.parse([])
        #expect(options.arguments.isEmpty)
        #expect(options.startsInHistory)
        #expect(!options.target)
    }

    @Test func parsesLongOptions() throws {
        let options = try Options.parse(["--target", "--keep", "--print-path", "--and-exit"])
        #expect(options.target)
        #expect(options.keep)
        #expect(options.printPath)
        #expect(options.andExit)
        #expect(!options.startsInHistory)
    }

    @Test func parsesClusteredShortOptions() throws {
        let options = try Options.parse(["-tkpx"])
        #expect(options.target)
        #expect(options.keep)
        #expect(options.printPath)
        #expect(options.andExit)
    }

    @Test func allCompactImpliesDragAll() throws {
        #expect(try Options.parse(["-A", "a.txt"]).dragAll)
        #expect(try Options.parse(["-a", "a.txt"]).dragAll)
        #expect(try !Options.parse(["a.txt"]).dragAll)
    }

    @Test(arguments: [
        (["--thumb-size", "128"], CGFloat(128)),
        (["--thumb-size=64"], CGFloat(64)),
        (["-s", "48"], CGFloat(48)),
        (["-s48"], CGFloat(48)),
    ])
    func parsesThumbSize(argv: [String], expected: CGFloat) throws {
        #expect(try Options.parse(argv).thumbSize == expected)
    }

    @Test func rejectsBadThumbSize() {
        #expect(throws: OptionError.self) { try Options.parse(["-s", "hello"]) }
        #expect(throws: OptionError.self) { try Options.parse(["-s", "9999"]) }
    }

    @Test func nameStyleFlags() throws {
        #expect(try Options.parse(["-f", "a"]).nameStyle == .basename)
        #expect(try Options.parse(["-F", "a"]).nameStyle == .fullPath)
        #expect(try Options.parse(["a"]).nameStyle == .relative)
    }

    @Test func doubleDashStopsOptionParsing() throws {
        let options = try Options.parse(["-t", "--", "--target", "-x"])
        #expect(options.target)
        #expect(!options.andExit)
        #expect(options.arguments == ["--target", "-x"])
    }

    @Test func loneDashIsAFileName() throws {
        #expect(try Options.parse(["-"]).arguments == ["-"])
    }

    @Test func helpVersionAndUnknownOptionsThrow() {
        #expect(throws: OptionError.self) { try Options.parse(["--help"]) }
        #expect(throws: OptionError.self) { try Options.parse(["--version"]) }
        #expect(throws: OptionError.self) { try Options.parse(["--bogus"]) }
        #expect(throws: OptionError.self) { try Options.parse(["-Z"]) }
    }

    @Test func historyFlags() throws {
        #expect(try Options.parse(["-H", "a.txt"]).showHistory)
        #expect(try Options.parse(["-H", "a.txt"]).startsInHistory)
        #expect(try !Options.parse(["-N", "a.txt"]).recordHistory)
    }
}

// MARK: - Item classification

struct DrakeItemTests {
    private let base = URL(fileURLWithPath: "/Users/someone/work")

    @Test func plainPathBecomesFileRelativeToBase() {
        let item = DrakeItem.fromArgument("docs/report.pdf", relativeTo: base)
        #expect(item.isFile)
        #expect(item.fileURL?.path == "/Users/someone/work/docs/report.pdf")
        #expect(item.uri.hasPrefix("file:///"))
    }

    @Test func remoteURIStaysAURI() {
        let item = DrakeItem.fromArgument("https://example.com/page", relativeTo: base)
        #expect(!item.isFile)
        #expect(item.uri == "https://example.com/page")
        #expect(item.dragText == "https://example.com/page")
    }

    @Test func fileURIBecomesAFile() {
        let item = DrakeItem.fromArgument("file:///etc/hosts", relativeTo: base)
        #expect(item.isFile)
        #expect(item.fileURL?.path == "/etc/hosts")
    }

    @Test func pathWithColonIsNotMistakenForAURI() {
        let item = DrakeItem.fromArgument("./weird:name.txt", relativeTo: base)
        #expect(item.isFile)
        #expect(item.fileURL?.lastPathComponent == "weird:name.txt")
    }

    @Test func labelHonoursNameStyle() {
        let item = DrakeItem.fromArgument("docs/report.pdf", relativeTo: base)
        #expect(item.label(style: .relative, relativeTo: base) == "docs/report.pdf")
        #expect(item.label(style: .basename, relativeTo: base) == "report.pdf")
        #expect(item.label(style: .fullPath, relativeTo: base) == "/Users/someone/work/docs/report.pdf")
    }

    @Test func labelFallsBackToAbsolutePathOutsideBase() {
        let item = DrakeItem.fromArgument("/etc/hosts", relativeTo: base)
        #expect(item.label(style: .relative, relativeTo: base) == "/etc/hosts")
    }

    @Test func outputLineRespectsPrintPath() {
        let file = DrakeItem.fromArgument("/etc/hosts", relativeTo: base)
        #expect(file.outputLine(printPath: true) == "/etc/hosts")
        #expect(file.outputLine(printPath: false) == "file:///etc/hosts")

        let uri = DrakeItem.uri("https://example.com")
        #expect(uri.outputLine(printPath: true) == "https://example.com")
    }

    @Test func pasteboardWriterOffersFileURLAndText() {
        let item = DrakeItem.fromArgument("/etc/hosts", relativeTo: base)
        let writer = ItemPasteboardWriter(item: item)
        let types = writer.writableTypes(for: .general)
        #expect(types.first == .fileURL)
        #expect(types.contains(.string))
        #expect(writer.pasteboardPropertyList(forType: .fileURL) as? String == "file:///etc/hosts")
        #expect(writer.pasteboardPropertyList(forType: .string) as? String == "/etc/hosts")
    }

    @Test func pasteboardWriterOmitsFileURLForRemoteURIs() {
        let writer = ItemPasteboardWriter(item: .uri("https://example.com"))
        #expect(!writer.writableTypes(for: .general).contains(.fileURL))
    }
}

// MARK: - Path shortening

struct PathFormattingTests {
    @Test func shortPathsAreLeftAlone() {
        #expect(PathFormatting.abbreviate("/etc/hosts") == "/etc/hosts")
    }

    @Test func longPathLosesItsMiddleDirectories() {
        let path = "/Volumes/backup/Documents/archive/2024/q3/reports/summary.pdf"
        let short = PathFormatting.abbreviate(path, limit: 40)
        #expect(short.contains(PathFormatting.ellipsis))
        #expect(short.hasSuffix("reports/summary.pdf"))
        #expect(short.hasPrefix("/Volumes/"))
        #expect(short.count <= 40)
    }

    @Test func keepsOnlyTheLastComponentWhenStillTooLong() {
        let path = "/aaaaaaaaaa/bbbbbbbbbb/cccccccccc/dddddddddd/eeeeeeeeee/file.mp3"
        let short = PathFormatting.abbreviate(path, limit: 30)
        #expect(short.hasSuffix("file.mp3"))
        #expect(short.count <= 30)
    }

    @Test func homeDirectoryIsTilded() {
        let path = NSHomeDirectory() + "/notes.txt"
        #expect(PathFormatting.abbreviate(path).hasPrefix("~/"))
    }

    @Test func middleTruncateKeepsBothEnds() {
        let text = String(repeating: "x", count: 50) + "END"
        let short = PathFormatting.middleTruncate(text, limit: 20)
        #expect(short.count == 20)
        #expect(short.hasPrefix("xx"))
        #expect(short.hasSuffix("END"))
        #expect(short.contains(PathFormatting.ellipsis))
    }

    @Test func itemLabelIsShortenedButTooltipIsNot() {
        let base = URL(fileURLWithPath: "/")
        let long = "/Volumes/backup/archive/2024/q3/reports/very-long-summary-name.pdf"
        let item = DrakeItem.fromArgument(long, relativeTo: base)
        let label = item.label(style: .fullPath, relativeTo: base)
        #expect(label.contains(PathFormatting.ellipsis))
        #expect(label.hasSuffix("very-long-summary-name.pdf"))
        // The real path stays available for tooltips and for the pasteboard.
        #expect(item.fileURL?.path == long)
        #expect(item.dragText == long)
    }
}

// MARK: - Selection

struct SelectionTests {
    private let ids = (0..<5).map { _ in UUID() }

    @Test func plainClickReplacesSelection() {
        var selection = Selection()
        selection.click(on: ids[1], in: ids, modifiers: [])
        selection.click(on: ids[3], in: ids, modifiers: [])
        #expect(selection.ids == [ids[3]])
    }

    @Test func commandClickToggles() {
        var selection = Selection()
        selection.click(on: ids[1], in: ids, modifiers: [])
        selection.click(on: ids[3], in: ids, modifiers: .command)
        #expect(selection.ids == [ids[1], ids[3]])
        selection.click(on: ids[3], in: ids, modifiers: .command)
        #expect(selection.ids == [ids[1]])
    }

    @Test func shiftClickSelectsRangeFromAnchor() {
        var selection = Selection()
        selection.click(on: ids[1], in: ids, modifiers: [])
        selection.click(on: ids[3], in: ids, modifiers: .shift)
        #expect(selection.ids == Set(ids[1...3]))
    }

    @Test func shiftClickBackwardsAlsoWorks() {
        var selection = Selection()
        selection.click(on: ids[3], in: ids, modifiers: [])
        selection.click(on: ids[0], in: ids, modifiers: .shift)
        #expect(selection.ids == Set(ids[0...3]))
    }

    @Test func shiftCommandClickAddsRangeToSelection() {
        var selection = Selection()
        selection.click(on: ids[0], in: ids, modifiers: [])
        selection.click(on: ids[2], in: ids, modifiers: .command)
        selection.click(on: ids[4], in: ids, modifiers: [.shift, .command])
        #expect(selection.ids == [ids[0], ids[2], ids[3], ids[4]])
    }

    @Test func contextMenuKeepsExistingMultipleSelection() {
        var selection = Selection()
        selection.click(on: ids[0], in: ids, modifiers: [])
        selection.click(on: ids[1], in: ids, modifiers: .command)
        selection.prepareForContextMenu(on: ids[1])
        #expect(selection.ids == [ids[0], ids[1]])

        selection.prepareForContextMenu(on: ids[4])
        #expect(selection.ids == [ids[4]])
    }

    @Test func arrowKeysMoveAndExtend() {
        var selection = Selection()
        selection.move(by: 1, in: ids, extending: false)
        #expect(selection.ids == [ids[0]])
        selection.move(by: 1, in: ids, extending: false)
        #expect(selection.ids == [ids[1]])
        selection.move(by: 1, in: ids, extending: true)
        #expect(selection.ids == [ids[1], ids[2]])
    }

    @Test func moveStaysInBounds() {
        var selection = Selection()
        selection.click(on: ids[4], in: ids, modifiers: [])
        selection.move(by: 1, in: ids, extending: false)
        #expect(selection.ids == [ids[4]])
    }

    @Test func pruneDropsVanishedRows() {
        var selection = Selection()
        selection.selectAll(ids)
        selection.prune(to: Array(ids.prefix(2)))
        #expect(selection.ids == Set(ids.prefix(2)))
    }
}

// MARK: - Per-type icons

@MainActor
struct FileTypeIconTests {
    private func icon(_ name: String) -> FileTypeIcon? {
        // Real files, so contentTypeKey resolves the way it does in the app.
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("DrakeIcons-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = directory.appendingPathComponent(name)
        try? Data("x".utf8).write(to: url)
        return FileTypeIcons.icon(for: .file(at: url))
    }

    @Test(arguments: [
        ("notes.txt", "doc.text"),
        ("data.csv", "tablecells"),
        ("sheet.tsv", "tablecells"),
        ("song.mp3", "music.note"),
        ("song.flac", "music.note"),
        ("voice.m4a", "music.note"),
        ("clip.mp4", "film"),
        ("clip.mov", "film"),
        ("clip.mkv", "film"),
        ("photo.png", "photo"),
        ("photo.heic", "photo"),
        ("paper.pdf", "doc.richtext"),
        ("bundle.zip", "doc.zipper"),
        ("bundle.tar.gz", "doc.zipper"),
        ("config.json", "curlybraces"),
        ("config.yaml", "curlybraces"),
        ("page.html", "globe"),
        ("main.swift", "chevron.left.slash.chevron.right"),
        ("script.py", "chevron.left.slash.chevron.right"),
        ("run.sh", "terminal"),
        ("readme.md", "text.alignleft"),
        ("server.log", "list.bullet.rectangle"),
        ("font.ttf", "textformat"),
        ("book.epub", "book"),
        ("image.dmg", "externaldrive"),
        ("notes.rtf", "doc.richtext"),
    ])
    func commonTypesGetTheirOwnSymbol(name: String, symbol: String) {
        #expect(icon(name)?.symbol == symbol, "\(name) should use \(symbol)")
    }

    @Test func foldersKeepTheFinderIcon() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("DrakeIcons-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        #expect(FileTypeIcons.icon(for: .file(at: directory)) == nil)
    }

    @Test func remoteURIsGetAGlobe() {
        #expect(FileTypeIcons.icon(for: .uri("https://example.com"))?.symbol == "globe")
    }

    @Test func missingFilesAreFlagged() {
        let gone = URL(fileURLWithPath: "/tmp/drake-does-not-exist-\(UUID().uuidString).txt")
        #expect(FileTypeIcons.icon(for: .file(at: gone))?.symbol == "questionmark.square.dashed")
    }
}

// MARK: - Layout and sweep selection

struct MetricsTests {
    @Test func listGrowsWithRowCountUpToTheCap() {
        let icon: CGFloat = 32
        let one = Metrics.visibleListHeight(rowCount: 1, iconSize: icon)
        let two = Metrics.visibleListHeight(rowCount: 2, iconSize: icon)
        let nine = Metrics.visibleListHeight(rowCount: 9, iconSize: icon)
        let twenty = Metrics.visibleListHeight(rowCount: 20, iconSize: icon)

        #expect(two - one == Metrics.rowHeight(iconSize: icon) + Metrics.rowSpacing)
        #expect(nine == twenty, "past 9 rows the list scrolls instead of growing")
        #expect(one == Metrics.rowHeight(iconSize: icon) + Metrics.listPaddingVertical * 2)
    }

    @Test func gridRowsFollowTheAvailableWidth() {
        #expect(Metrics.gridRows(count: 4, iconSize: 96, width: 380) == 2)
        #expect(Metrics.gridRows(count: 1, iconSize: 96, width: 380) == 1)
        #expect(Metrics.gridRows(count: 0, iconSize: 96, width: 380) == 1)
    }
}

@MainActor
struct MarqueeSelectionTests {
    private func makeView(rowCount: Int, scrollOffset: CGFloat = 0) -> MarqueeSelectionNSView {
        let view = MarqueeSelectionNSView()
        view.rowCount = rowCount
        view.rowHeight = 42
        view.rowSpacing = 4
        view.topInset = 10
        view.scrollOffset = scrollOffset
        return view
    }

    @Test func sweepPicksUpTheRowsItCrosses() {
        let view = makeView(rowCount: 5)
        // Rows start at y=10 and repeat every 46pt.
        #expect(view.rowIndices(in: CGRect(x: 0, y: 12, width: 300, height: 4)) == [0])
        // Rows 0 and 1 span y=10...98; row 2 only begins at y=102.
        #expect(view.rowIndices(in: CGRect(x: 0, y: 12, width: 300, height: 90)) == [0, 1])
        #expect(view.rowIndices(in: CGRect(x: 0, y: 12, width: 300, height: 95)) == [0, 1, 2])
        #expect(view.rowIndices(in: CGRect(x: 0, y: 0, width: 300, height: 400)) == [0, 1, 2, 3, 4])
    }

    @Test func sweepBelowTheLastRowSelectsNothing() {
        let view = makeView(rowCount: 2)
        #expect(view.rowIndices(in: CGRect(x: 0, y: 200, width: 300, height: 50)).isEmpty)
    }

    @Test func sweepAccountsForScrollPosition() {
        let scrolled = makeView(rowCount: 10, scrollOffset: 92)
        // Two rows have scrolled off the top, so the top of the view is row 2.
        #expect(scrolled.rowIndices(in: CGRect(x: 0, y: 12, width: 300, height: 4)) == [2])
    }

    @Test func emptyListSweepsNothing() {
        #expect(makeView(rowCount: 0).rowIndices(in: CGRect(x: 0, y: 0, width: 300, height: 300)).isEmpty)
    }
}

// MARK: - History

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

// MARK: - Model wiring

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
}
