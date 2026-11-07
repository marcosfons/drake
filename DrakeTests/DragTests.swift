//
//  DragTests.swift
//  DrakeTests
//

import AppKit
import Foundation
import Testing

@testable import Drake

struct DragURITests {
    @Test func symlinkDragsTheRealFile() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let target = directory.appendingPathComponent("real.md")
        try Data("# hi\n".utf8).write(to: target)
        let link = directory.appendingPathComponent("CLAUDE.md")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        let dragged = try #require(URL(string: DrakeItem.file(at: link).dragURI))
        #expect(dragged.lastPathComponent == "real.md")
        // Fully resolved: no component of the path is itself a link.
        #expect(dragged.path == (dragged.path as NSString).resolvingSymlinksInPath
            || dragged.path.hasPrefix("/private/"))
        #expect(DrakeItem.file(at: target).dragURI == DrakeItem.file(at: link).dragURI)
    }

    @Test func remoteURIIsUnchanged() {
        let item = DrakeItem.uri("https://example.com/a")
        #expect(item.dragURI == "https://example.com/a")
    }
}

@MainActor
struct FilePromiseTests {
    private func tempDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @Test func textFilesAreDraggedAsPromises() throws {
        let directory = try tempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        for name in ["CLAUDE.md", "notes.txt", "data.csv", "config.json", "main.swift", "index.html"] {
            let url = directory.appendingPathComponent(name)
            try Data("x".utf8).write(to: url)
            let item = DrakeItem.file(at: url)
            #expect(item.dragsAsFilePromise, "\(name)")
            #expect(item.pasteboardWriter(asAttachment: true) is DataFilePromise, "\(name)")
            #expect(item.pasteboardWriter(asAttachment: false) is ItemPasteboardWriter, "\(name)")
        }
    }

    @Test func otherFilesKeepTheFileURL() throws {
        let directory = try tempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        for name in ["photo.png", "archive.zip", "report.pdf"] {
            let url = directory.appendingPathComponent(name)
            try Data("x".utf8).write(to: url)
            #expect(!DrakeItem.file(at: url).dragsAsFilePromise, "\(name)")
        }
        #expect(!DrakeItem.file(at: directory).dragsAsFilePromise)
        #expect(!DrakeItem.uri("https://example.com/a.md").dragsAsFilePromise)
        #expect(!DrakeItem.file(at: directory.appendingPathComponent("gone.md")).dragsAsFilePromise)
    }

    @Test func promiseCopiesTheRealFileUnderItsName() throws {
        let directory = try tempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("CLAUDE.md")
        try Data("# drake\n".utf8).write(to: source)

        let promise = try #require(DrakeItem.file(at: source).pasteboardWriter(asAttachment: true) as? DataFilePromise)
        #expect(promise.fileType == "public.data")
        #expect(promise.filePromiseProvider(promise, fileNameForType: "public.data") == "CLAUDE.md")

        let destination = directory.appendingPathComponent("dropped.md")
        var failure: Error?
        promise.filePromiseProvider(promise, writePromiseTo: destination) { failure = $0 }
        #expect(failure == nil)
        #expect(try String(contentsOf: destination, encoding: .utf8) == "# drake\n")
    }
}

struct DropTargetAppTests {
    private let whatsapp = DropTargetApp.Window(
        bounds: CGRect(x: 100, y: 100, width: 400, height: 300), bundleID: "net.whatsapp.WhatsApp")
    private let terminal = DropTargetApp.Window(
        bounds: CGRect(x: 600, y: 100, width: 400, height: 300), bundleID: "com.apple.Terminal")

    @Test func overWhatsAppOffersAttachments() {
        #expect(DropTargetApp.wantsAttachments(at: CGPoint(x: 300, y: 250), windows: [whatsapp, terminal]))
    }

    @Test func switchesJustBeforeReachingWhatsApp() {
        // 20pt left of its window: inside the margin.
        #expect(DropTargetApp.wantsAttachments(at: CGPoint(x: 80, y: 250), windows: [whatsapp]))
        #expect(!DropTargetApp.wantsAttachments(at: CGPoint(x: 20, y: 250), windows: [whatsapp]))
    }

    @Test func otherAppsKeepURLs() {
        #expect(!DropTargetApp.wantsAttachments(at: CGPoint(x: 700, y: 250), windows: [whatsapp, terminal]))
        #expect(!DropTargetApp.wantsAttachments(at: CGPoint(x: 2000, y: 2000), windows: [whatsapp, terminal]))
    }

    @Test func windowInFrontHidesWhatsApp() {
        let covering = DropTargetApp.Window(bounds: CGRect(x: 200, y: 150, width: 100, height: 100), bundleID: "com.apple.Terminal")
        #expect(!DropTargetApp.wantsAttachments(at: CGPoint(x: 250, y: 200), windows: [covering, whatsapp]))
        #expect(DropTargetApp.wantsAttachments(at: CGPoint(x: 450, y: 200), windows: [covering, whatsapp]))
    }
}
