//
//  DrakeItemTests.swift
//  DrakeTests
//

import AppKit
import Foundation
import Testing

@testable import Drake

struct DrakeItemTests {
    private let base = URL(fileURLWithPath: "/Users/someone/work")

    private func detail(_ url: URL, in directory: URL) -> String {
        DrakeItem.file(at: url).detail(FileInfo(url: url), relativeTo: directory)
    }

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

    @Test func detailOmitsTheLocationForFilesInTheWorkingDirectory() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("DrakeDetail-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let here = directory.appendingPathComponent("here.txt")
        try Data("1234".utf8).write(to: here)
        let line = detail(here, in: directory)
        #expect(line == "4 bytes", "no \".\" and no separator for the current folder")
        #expect(!line.contains("."))
        #expect(!line.contains("-"))

        // A subfolder is somewhere else, so it is worth naming.
        let nested = directory.appendingPathComponent("sub", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        let below = nested.appendingPathComponent("there.txt")
        try Data("1234".utf8).write(to: below)
        #expect(detail(below, in: directory).contains(" - "))
    }

    @Test func detailForFoldersAndMissingFilesInTheWorkingDirectory() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("DrakeDetail-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let folder = directory.appendingPathComponent("stuff", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        #expect(detail(folder, in: directory) == "Folder")

        let gone = directory.appendingPathComponent("gone.txt")
        #expect(detail(gone, in: directory) == "missing")
    }

    @Test func unreadableSizeShowsNothingRatherThanASeparator() {
        // A path that cannot be stat'd yields no size, and no bare hyphen.
        let gone = URL(fileURLWithPath: "/tmp/drake-absent-\(UUID().uuidString).txt")
        #expect(FileInfo(url: gone).sizeDescription.isEmpty)
    }

    /// A file offers `public.file-url` and nothing else, the same set Finder
    /// sends. Adding plain text makes sandboxed Catalyst targets such as WhatsApp
    /// refuse the drag at drag-enter, so this is load-bearing, not tidiness.
    @Test func fileOffersFileURLAlone() {
        let item = DrakeItem.fromArgument("/etc/hosts", relativeTo: base)
        let writer = ItemPasteboardWriter(item: item)
        #expect(writer.writableTypes(for: .general) == [.fileURL])
        #expect(writer.pasteboardPropertyList(forType: .fileURL) as? String == "file:///private/etc/hosts", "/etc is a symlink; the real path is dragged")
    }

    /// The text a URI hands over is the path for a file and the URI otherwise,
    /// never a percent-encoded file URL.
    @Test func pasteboardWriterWritesPathAsText() {
        let file = DrakeItem.fromArgument("/etc/hosts", relativeTo: base)
        #expect(ItemPasteboardWriter(item: file)
            .pasteboardPropertyList(forType: .string) as? String == "/etc/hosts")
        #expect(ItemPasteboardWriter(item: .uri("https://example.com"))
            .pasteboardPropertyList(forType: .string) as? String == "https://example.com")
    }

    /// A bare URI has no file to offer, so it keeps URL and text: those are the
    /// only ways a target can take it.
    @Test func pasteboardWriterOmitsFileURLForRemoteURIs() {
        let writer = ItemPasteboardWriter(item: .uri("https://example.com"))
        let types = writer.writableTypes(for: .general)
        #expect(!types.contains(.fileURL))
        #expect(types == [.URL, .string])
    }
}
