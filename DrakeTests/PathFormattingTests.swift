//
//  PathFormattingTests.swift
//  DrakeTests
//

import AppKit
import Foundation
import Testing

@testable import Drake

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
