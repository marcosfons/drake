//
//  FileInfo.swift
//  Drake
//
//  What the interface shows about a file - whether it exists, whether it is a
//  folder, its size and its type - read in a single resource-values call.
//
//  Rows read it through `FileInfoCache`, so drawing a list never touches the
//  disk once per row per render. The cache is dropped whenever drake becomes
//  active again, since the files may have changed while it was in the
//  background. Anything that acts on a file (starting a drag, refusing a
//  missing argument) checks the disk directly instead.
//

import Foundation
import Observation
import UniformTypeIdentifiers

nonisolated struct FileInfo: Equatable, Sendable {
    var exists: Bool
    var isDirectory: Bool
    /// Nil when the size cannot be read, or for folders.
    var size: Int?
    var contentType: UTType?

    /// Remote URIs have no file behind them; they always "exist".
    static let remote = FileInfo(exists: true, isDirectory: false, size: nil, contentType: nil)

    init(exists: Bool, isDirectory: Bool, size: Int?, contentType: UTType?) {
        self.exists = exists
        self.isDirectory = isDirectory
        self.size = size
        self.contentType = contentType
    }

    /// Reads `url` from disk. Nil means a remote item.
    init(url: URL?) {
        guard let url else {
            self = .remote
            return
        }
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .fileSizeKey, .contentTypeKey]
        guard let values = try? url.resourceValues(forKeys: keys) else {
            self.init(
                exists: false,
                isDirectory: false,
                size: nil,
                contentType: UTType(filenameExtension: url.pathExtension)
            )
            return
        }
        let isDirectory = values.isDirectory ?? false
        self.init(
            exists: true,
            isDirectory: isDirectory,
            size: isDirectory ? nil : values.fileSize,
            contentType: values.contentType ?? UTType(filenameExtension: url.pathExtension)
        )
    }

    /// "4 KB", or empty when the size is unknown so nothing is shown for it.
    var sizeDescription: String {
        guard let size else { return "" }
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
}

@Observable
final class FileInfoCache {
    static let shared = FileInfoCache()

    /// Bumped on invalidation. Reading it in `info(for:)` makes every view
    /// that showed file details redraw once the cache is dropped.
    private var generation = 0
    @ObservationIgnored private var entries: [URL: FileInfo] = [:]

    func info(for item: DrakeItem) -> FileInfo {
        _ = generation
        guard let url = item.fileURL else { return .remote }
        if let cached = entries[url] { return cached }
        let info = FileInfo(url: url)
        entries[url] = info
        return info
    }

    func invalidate() {
        entries.removeAll()
        generation += 1
    }
}
