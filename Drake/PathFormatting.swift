//
//  PathFormatting.swift
//  Drake
//
//  Long paths are shortened by eliding whole directories out of the middle,
//  so the useful ends stay readable:
//
//      /Users/marcos/Documents/archive/2024/q3/reports/summary.pdf
//      /Users/…/reports/summary.pdf
//

import Foundation

nonisolated enum PathFormatting {
    static let ellipsis = "…"

    /// Shortens `path` to roughly `limit` characters, keeping the first
    /// component and the last `keepingLast` components.
    static func abbreviate(_ path: String, limit: Int = 46, keepingLast: Int = 2) -> String {
        let tilded = (path as NSString).abbreviatingWithTildeInPath
        guard tilded.count > limit else { return tilded }

        let isAbsolute = tilded.hasPrefix("/")
        var components = tilded.split(separator: "/").map(String.init)
        guard components.count > keepingLast + 1 else {
            return middleTruncate(tilded, limit: limit)
        }

        let head = components.removeFirst()
        let tail = components.suffix(keepingLast)
        let prefix = isAbsolute ? "/" : ""

        var candidate = prefix + ([head, ellipsis] + tail).joined(separator: "/")
        if candidate.count <= limit { return candidate }

        // Still too long: keep fewer trailing components, then fall back to
        // truncating what is left.
        if keepingLast > 1 {
            candidate = prefix + ([head, ellipsis] + components.suffix(1)).joined(separator: "/")
            if candidate.count <= limit { return candidate }
        }
        return middleTruncate(candidate, limit: limit)
    }

    /// Character-level fallback: drop the middle of the string.
    static func middleTruncate(_ text: String, limit: Int) -> String {
        guard text.count > limit, limit > 4 else { return text }
        let keep = limit - ellipsis.count
        let leading = keep - keep / 2
        let trailing = keep / 2
        return text.prefix(leading) + ellipsis + text.suffix(trailing)
    }
}
