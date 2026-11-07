//
//  FileInfoTests.swift
//  DrakeTests
//

import Foundation
import Testing
import UniformTypeIdentifiers

@testable import Drake

@MainActor
struct FileInfoTests {
    private func makeDirectory() throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("DrakeInfo-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @Test func readsSizeKindAndType() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("data.json")
        try Data("{}".utf8).write(to: file)

        let info = FileInfo(url: file)
        #expect(info.exists)
        #expect(!info.isDirectory)
        #expect(info.size == 2)
        #expect(info.contentType?.conforms(to: .json) == true)

        let folder = FileInfo(url: directory)
        #expect(folder.isDirectory)
        #expect(folder.size == nil, "folders show Folder, not a size")
    }

    @Test func missingFilesKeepTheirTypeButNoSize() {
        let info = FileInfo(url: URL(fileURLWithPath: "/tmp/drake-gone-\(UUID().uuidString).png"))
        #expect(!info.exists)
        #expect(info.size == nil)
        #expect(info.contentType?.conforms(to: .image) == true)
    }

    @Test func remoteItemsAlwaysExist() {
        #expect(FileInfo(url: nil) == .remote)
        #expect(FileInfo.remote.exists)
    }

    @Test func cacheServesStaleDataUntilInvalidated() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("later.txt")
        let item = DrakeItem.file(at: url)
        let cache = FileInfoCache()

        #expect(!cache.info(for: item).exists)
        try Data("x".utf8).write(to: url)
        #expect(!cache.info(for: item).exists, "served from the cache")
        cache.invalidate()
        #expect(cache.info(for: item).exists)
    }
}
