//
//  Log.swift
//  Drake
//
//  Logging, in two layers:
//
//  - Everything goes to the unified log under the app's subsystem, so it shows
//    up in Console.app and in `make log`
//    (`log show --predicate 'subsystem == "com.marcos.Drake"'`).
//  - Warnings and errors are also appended to ~/Library/Logs/Drake/drake.log,
//    a small file that outlives the unified log's retention, which Help >
//    Show Problem Log opens in Console.
//
//  `--verbose` mirrors every message to standard error as well.
//

import Foundation
import OSLog
import Synchronization

nonisolated struct Log: Sendable {
    static let subsystem = Bundle.main.bundleIdentifier ?? "com.marcos.Drake"

    static let app = Log(category: "app")
    static let drag = Log(category: "drag")
    static let drop = Log(category: "drop")
    static let history = Log(category: "history")
    static let thumbnails = Log(category: "thumbnails")

    /// Whether messages are mirrored to standard error. Set once at launch
    /// from `--verbose`.
    static var echoesToStandardError: Bool {
        get { echo.load(ordering: .relaxed) }
        set { echo.store(newValue, ordering: .relaxed) }
    }

    private static let echo = Atomic<Bool>(false)

    let category: String
    private let logger: Logger

    init(category: String) {
        self.category = category
        self.logger = Logger(subsystem: Self.subsystem, category: category)
    }

    /// Developer detail; kept in memory only, never in the problem log.
    func debug(_ message: String) {
        logger.debug("\(message, privacy: .public)")
        echo("debug", message)
    }

    /// Normal events worth seeing in `--verbose`: mode, drags, drops.
    func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
        echo("info", message)
    }

    /// Something went wrong but drake carried on.
    func warning(_ message: String) {
        logger.warning("\(message, privacy: .public)")
        echo("warning", message)
        ProblemLog.shared.append(level: "warning", category: category, message: message)
    }

    /// An operation failed: history not saved, a drop copy failed.
    func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
        echo("error", message)
        ProblemLog.shared.append(level: "error", category: category, message: message)
    }

    private func echo(_ level: String, _ message: String) {
        guard Self.echoesToStandardError else { return }
        FileHandle.standardError.write(Data("[\(category)] \(level): \(message)\n".utf8))
    }
}

/// Appends warnings and errors to a plain-text file, rotating it once it
/// passes `maximumSize` so it never grows without bound.
nonisolated final class ProblemLog: Sendable {
    static let shared = ProblemLog(fileURL: defaultFileURL)

    static var defaultFileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Logs/Drake/drake.log", directoryHint: .notDirectory)
    }

    let fileURL: URL
    let maximumSize: Int
    private let queue = DispatchQueue(label: "com.marcos.Drake.problem-log", qos: .utility)

    init(fileURL: URL, maximumSize: Int = 256 * 1024) {
        self.fileURL = fileURL
        self.maximumSize = maximumSize
    }

    /// The previous file, kept after rotation.
    var rotatedFileURL: URL {
        fileURL.deletingPathExtension().appendingPathExtension("old.log")
    }

    func append(level: String, category: String, message: String, date: Date = .now) {
        let line = "\(date.formatted(.iso8601)) [\(category)] \(level): \(message)\n"
        queue.async { self.write(line) }
    }

    /// Blocks until every pending line is on disk. For tests and for opening
    /// the file from the Help menu.
    func flush() {
        queue.sync {}
    }

    private func write(_ line: String) {
        let manager = FileManager.default
        do {
            try manager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if let size = try? manager.attributesOfItem(atPath: fileURL.path)[.size] as? Int, size > maximumSize {
                try? manager.removeItem(at: rotatedFileURL)
                try manager.moveItem(at: fileURL, to: rotatedFileURL)
            }
            if !manager.fileExists(atPath: fileURL.path) {
                manager.createFile(atPath: fileURL.path, contents: nil)
            }
            let handle = try FileHandle(forWritingTo: fileURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(line.utf8))
        } catch {
            // Nowhere left to report it but the unified log.
            Logger(subsystem: Log.subsystem, category: "log")
                .fault("Could not write the problem log: \(error.localizedDescription, privacy: .public)")
        }
    }
}
