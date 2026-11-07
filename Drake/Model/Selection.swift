//
//  Selection.swift
//  Drake
//
//  Finder-style list selection: click replaces, ⌘-click toggles, ⇧-click
//  extends from the anchor. Used by the source list and by expanded history
//  entries, so both behave the same way.
//

import AppKit
import Foundation

nonisolated struct Selection: Equatable {
    var ids: Set<UUID> = []
    /// Row the next ⇧-click extends from.
    var anchor: UUID?

    var isEmpty: Bool { ids.isEmpty }
    var count: Int { ids.count }

    func contains(_ id: UUID) -> Bool { ids.contains(id) }

    mutating func click(on id: UUID, in order: [UUID], modifiers: NSEvent.ModifierFlags) {
        if modifiers.contains(.shift),
           let anchor,
           let start = order.firstIndex(of: anchor),
           let end = order.firstIndex(of: id) {
            let range = start <= end ? start...end : end...start
            let extended = Set(order[range])
            ids = modifiers.contains(.command) ? ids.union(extended) : extended
            return
        }

        if modifiers.contains(.command) {
            if ids.contains(id) {
                ids.remove(id)
            } else {
                ids.insert(id)
            }
            anchor = id
            return
        }

        ids = [id]
        anchor = id
    }

    /// Right-clicking outside the current selection selects that row only.
    mutating func prepareForContextMenu(on id: UUID) {
        guard !ids.contains(id) else { return }
        ids = [id]
        anchor = id
    }

    mutating func selectAll(_ order: [UUID]) {
        ids = Set(order)
        anchor = order.first
    }

    mutating func clear() {
        ids.removeAll()
        anchor = nil
    }

    /// Keeps the selection in step with a list that lost rows.
    mutating func prune(to order: [UUID]) {
        let valid = Set(order)
        ids.formIntersection(valid)
        if let anchor, !valid.contains(anchor) { self.anchor = ids.first }
    }

    /// Moves by one row for ↑/↓, optionally extending.
    mutating func move(by offset: Int, in order: [UUID], extending: Bool) {
        guard !order.isEmpty else { return }
        let current = anchor.flatMap { order.firstIndex(of: $0) }
        let fallback = offset > 0 ? -1 : order.count
        let next = min(max((current ?? fallback) + offset, 0), order.count - 1)
        let id = order[next]
        if extending {
            ids.insert(id)
            anchor = id
        } else {
            ids = [id]
            anchor = id
        }
    }
}
