//
//  HistorySection.swift
//  Drake
//
//  The history list is grouped the way Safari and Notes group by date: pinned
//  runs first, then Today, Yesterday, Previous 7 Days and Earlier.
//

import Foundation

nonisolated struct HistorySection: Identifiable, Equatable {
    enum Kind: Int, CaseIterable {
        case pinned
        case today
        case yesterday
        case previousWeek
        case earlier

        var title: String {
            switch self {
            case .pinned: "Pinned"
            case .today: "Today"
            case .yesterday: "Yesterday"
            case .previousWeek: "Previous 7 Days"
            case .earlier: "Earlier"
            }
        }
    }

    let kind: Kind
    let entries: [HistoryEntry]

    var id: Kind { kind }

    /// Splits `entries` (already newest first) into non-empty sections, in
    /// display order. Each entry keeps its relative order.
    static func group(
        _ entries: [HistoryEntry],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [HistorySection] {
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today) ?? today

        func kind(of entry: HistoryEntry) -> Kind {
            if entry.pinned { return .pinned }
            if entry.date >= today { return .today }
            if entry.date >= yesterday { return .yesterday }
            if entry.date >= weekAgo { return .previousWeek }
            return .earlier
        }

        let grouped = Dictionary(grouping: entries, by: kind)
        return Kind.allCases.compactMap { kind in
            guard let entries = grouped[kind], !entries.isEmpty else { return nil }
            return HistorySection(kind: kind, entries: entries)
        }
    }

    /// Short time for the trailing edge of a row: the time of day for today
    /// and yesterday, the date otherwise.
    static func timestamp(for date: Date, in kind: Kind) -> String {
        switch kind {
        case .today, .yesterday:
            date.formatted(date: .omitted, time: .shortened)
        case .pinned, .previousWeek, .earlier:
            date.formatted(.dateTime.month(.abbreviated).day())
        }
    }
}
