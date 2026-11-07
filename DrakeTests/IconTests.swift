//
//  IconTests.swift
//  DrakeTests
//

import AppKit
import Foundation
import Testing

@testable import Drake

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
        return FileTypeIcons.icon(for: .file(at: url), info: FileInfo(url: url))
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
        #expect(FileTypeIcons.icon(for: .file(at: directory), info: FileInfo(url: directory)) == nil)
    }

    @Test func remoteURIsGetAGlobe() {
        #expect(FileTypeIcons.icon(for: .uri("https://example.com"), info: .remote)?.symbol == "globe")
    }

    @Test func missingFilesAreFlagged() {
        let gone = URL(fileURLWithPath: "/tmp/drake-does-not-exist-\(UUID().uuidString).txt")
        #expect(FileTypeIcons.icon(for: .file(at: gone), info: FileInfo(url: gone))?.symbol == "questionmark.square.dashed")
    }
}

struct ThumbnailChoiceTests {
    @Test func picturesAndVideoGetThumbnails() {
        for name in ["photo.png", "photo.JPG", "shot.heic", "clip.mov", "clip.mp4"] {
            #expect(Thumbnailer.wantsThumbnail(for: FileInfo(url: URL(fileURLWithPath: "/tmp/\(name)")).contentType), "\(name)")
        }
    }

    @Test func documentsUseTheTypeIcon() {
        for name in ["notes.txt", "data.csv", "README.md", "config.json", "main.swift",
                     "index.html", "report.pdf", "archive.zip", "no-extension"] {
            #expect(!Thumbnailer.wantsThumbnail(for: FileInfo(url: URL(fileURLWithPath: "/tmp/\(name)")).contentType), "\(name)")
        }
    }
}
