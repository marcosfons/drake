//
//  SelectionTests.swift
//  DrakeTests
//

import AppKit
import Foundation
import Testing

@testable import Drake

struct SelectionTests {
    private let ids = (0..<5).map { _ in UUID() }

    @Test func plainClickReplacesSelection() {
        var selection = Selection()
        selection.click(on: ids[1], in: ids, modifiers: [])
        selection.click(on: ids[3], in: ids, modifiers: [])
        #expect(selection.ids == [ids[3]])
    }

    @Test func commandClickToggles() {
        var selection = Selection()
        selection.click(on: ids[1], in: ids, modifiers: [])
        selection.click(on: ids[3], in: ids, modifiers: .command)
        #expect(selection.ids == [ids[1], ids[3]])
        selection.click(on: ids[3], in: ids, modifiers: .command)
        #expect(selection.ids == [ids[1]])
    }

    @Test func shiftClickSelectsRangeFromAnchor() {
        var selection = Selection()
        selection.click(on: ids[1], in: ids, modifiers: [])
        selection.click(on: ids[3], in: ids, modifiers: .shift)
        #expect(selection.ids == Set(ids[1...3]))
    }

    @Test func shiftClickBackwardsAlsoWorks() {
        var selection = Selection()
        selection.click(on: ids[3], in: ids, modifiers: [])
        selection.click(on: ids[0], in: ids, modifiers: .shift)
        #expect(selection.ids == Set(ids[0...3]))
    }

    @Test func shiftCommandClickAddsRangeToSelection() {
        var selection = Selection()
        selection.click(on: ids[0], in: ids, modifiers: [])
        selection.click(on: ids[2], in: ids, modifiers: .command)
        selection.click(on: ids[4], in: ids, modifiers: [.shift, .command])
        #expect(selection.ids == [ids[0], ids[2], ids[3], ids[4]])
    }

    @Test func contextMenuKeepsExistingMultipleSelection() {
        var selection = Selection()
        selection.click(on: ids[0], in: ids, modifiers: [])
        selection.click(on: ids[1], in: ids, modifiers: .command)
        selection.prepareForContextMenu(on: ids[1])
        #expect(selection.ids == [ids[0], ids[1]])

        selection.prepareForContextMenu(on: ids[4])
        #expect(selection.ids == [ids[4]])
    }

    @Test func arrowKeysMoveAndExtend() {
        var selection = Selection()
        selection.move(by: 1, in: ids, extending: false)
        #expect(selection.ids == [ids[0]])
        selection.move(by: 1, in: ids, extending: false)
        #expect(selection.ids == [ids[1]])
        selection.move(by: 1, in: ids, extending: true)
        #expect(selection.ids == [ids[1], ids[2]])
    }

    @Test func moveStaysInBounds() {
        var selection = Selection()
        selection.click(on: ids[4], in: ids, modifiers: [])
        selection.move(by: 1, in: ids, extending: false)
        #expect(selection.ids == [ids[4]])
    }

    @Test func pruneDropsVanishedRows() {
        var selection = Selection()
        selection.selectAll(ids)
        selection.prune(to: Array(ids.prefix(2)))
        #expect(selection.ids == Set(ids.prefix(2)))
    }
}
