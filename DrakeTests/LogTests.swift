//
//  LogTests.swift
//  DrakeTests
//

import Foundation
import Testing

@testable import Drake

struct ProblemLogTests {
    private func makeLog(maximumSize: Int = 1024) -> (ProblemLog, URL) {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("DrakeLog-\(UUID().uuidString)")
        return (ProblemLog(fileURL: directory.appendingPathComponent("drake.log"), maximumSize: maximumSize), directory)
    }

    @Test func appendsOneLinePerProblem() throws {
        let (log, directory) = makeLog()
        defer { try? FileManager.default.removeItem(at: directory) }

        log.append(level: "error", category: "history", message: "Could not save")
        log.append(level: "warning", category: "drop", message: "Refused a drop")
        log.flush()

        let lines = try String(contentsOf: log.fileURL, encoding: .utf8).split(separator: "\n")
        #expect(lines.count == 2)
        #expect(lines[0].hasSuffix("[history] error: Could not save"))
        #expect(lines[1].hasSuffix("[drop] warning: Refused a drop"))
    }

    @Test func rotatesOncePastTheSizeLimit() throws {
        let (log, directory) = makeLog(maximumSize: 200)
        defer { try? FileManager.default.removeItem(at: directory) }

        for index in 0..<20 {
            log.append(level: "error", category: "test", message: "problem number \(index)")
        }
        log.flush()

        let current = try Data(contentsOf: log.fileURL)
        #expect(FileManager.default.fileExists(atPath: log.rotatedFileURL.path))
        #expect(current.count < 400, "the live file starts over after rotating")
    }
}
