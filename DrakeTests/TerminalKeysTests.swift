//
//  TerminalKeysTests.swift
//  DrakeTests
//

import AppKit
import Foundation
import Testing

@testable import Drake

struct TerminalKeysTests {
    @Test func qQuits() {
        #expect(TerminalKeys.asksToQuit(Array("q".utf8)))
        #expect(TerminalKeys.asksToQuit(Array("Q".utf8)))
        #expect(TerminalKeys.asksToQuit(Array("xq".utf8)))
    }

    @Test func otherKeysDoNot() {
        #expect(!TerminalKeys.asksToQuit(Array("a".utf8)))
        #expect(!TerminalKeys.asksToQuit([0x1b]))             // Escape
        #expect(!TerminalKeys.asksToQuit([0x1b, 0x5b, 0x41])) // Up arrow
        #expect(!TerminalKeys.asksToQuit([UInt8]()))
    }
}
