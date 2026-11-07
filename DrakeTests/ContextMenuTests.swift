//
//  ContextMenuTests.swift
//  DrakeTests
//

import AppKit
import Testing

@testable import Drake

@MainActor
struct ContextMenuTests {
    @Test func itemsRunTheirActionsAndSeparatorsAreKept() throws {
        var ran: [String] = []
        let menu = ContextMenu.make([
            .action("One") { ran.append("one") },
            .separator,
            .action("Two") { ran.append("two") },
        ])
        #expect(menu.items.map(\.title) == ["One", "", "Two"])
        #expect(menu.items[1].isSeparatorItem)

        let two = try #require(menu.items.last)
        // The handler is kept alive by the item itself, not a global cache.
        #expect(two.representedObject != nil)
        NSApplication.shared.sendAction(try #require(two.action), to: two.target, from: two)
        #expect(ran == ["two"])
    }
}
