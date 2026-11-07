//
//  OptionsTests.swift
//  DrakeTests
//

import AppKit
import Foundation
import Testing

@testable import Drake

struct OptionParsingTests {
    @Test func defaultsToHistoryWithNoArguments() throws {
        let options = try Options.parse([])
        #expect(options.arguments.isEmpty)
        #expect(options.startsInHistory)
        #expect(!options.target)
    }

    @Test func parsesLongOptions() throws {
        let options = try Options.parse(["--target", "--keep", "--print-path", "--and-exit"])
        #expect(options.target)
        #expect(options.keep)
        #expect(options.printPath)
        #expect(options.andExit)
        #expect(!options.startsInHistory)
    }

    @Test func parsesClusteredShortOptions() throws {
        let options = try Options.parse(["-tkpx"])
        #expect(options.target)
        #expect(options.keep)
        #expect(options.printPath)
        #expect(options.andExit)
    }

    @Test func allCompactImpliesDragAll() throws {
        #expect(try Options.parse(["-A", "a.txt"]).dragAll)
        #expect(try Options.parse(["-a", "a.txt"]).dragAll)
        #expect(try !Options.parse(["a.txt"]).dragAll)
    }

    @Test(arguments: [
        (["--thumb-size", "128"], CGFloat(128)),
        (["--thumb-size=64"], CGFloat(64)),
        (["-s", "48"], CGFloat(48)),
        (["-s48"], CGFloat(48)),
    ])
    func parsesThumbSize(argv: [String], expected: CGFloat) throws {
        #expect(try Options.parse(argv).thumbSize == expected)
    }

    @Test func rejectsBadThumbSize() {
        #expect(throws: OptionError.self) { try Options.parse(["-s", "hello"]) }
        #expect(throws: OptionError.self) { try Options.parse(["-s", "9999"]) }
    }

    @Test func nameStyleFlags() throws {
        #expect(try Options.parse(["-f", "a"]).nameStyle == .basename)
        #expect(try Options.parse(["-F", "a"]).nameStyle == .fullPath)
        #expect(try Options.parse(["a"]).nameStyle == .relative)
    }

    @Test func doubleDashStopsOptionParsing() throws {
        let options = try Options.parse(["-t", "--", "--target", "-x"])
        #expect(options.target)
        #expect(!options.andExit)
        #expect(options.arguments == ["--target", "-x"])
    }

    @Test func loneDashIsAFileName() throws {
        #expect(try Options.parse(["-"]).arguments == ["-"])
    }

    @Test func helpVersionAndUnknownOptionsThrow() {
        #expect(throws: OptionError.self) { try Options.parse(["--help"]) }
        #expect(throws: OptionError.self) { try Options.parse(["--version"]) }
        #expect(throws: OptionError.self) { try Options.parse(["--bogus"]) }
        #expect(throws: OptionError.self) { try Options.parse(["-Z"]) }
    }

    @Test func historyFlags() throws {
        #expect(try Options.parse(["-H", "a.txt"]).showHistory)
        #expect(try Options.parse(["-H", "a.txt"]).startsInHistory)
        #expect(try !Options.parse(["-N", "a.txt"]).recordHistory)
    }
}
