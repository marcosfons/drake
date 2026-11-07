//
//  Options.swift
//  Drake
//
//  Command-line parsing. The option set mirrors mwh/dragon so muscle memory
//  and existing scripts carry over, plus two options for the history browser.
//

import Foundation

/// How a file's label is rendered in the window.
nonisolated enum NameStyle {
    /// Path relative to the working directory when the file lives under it,
    /// absolute otherwise. This is dragon's default.
    case relative
    /// Basename only (`--name-only`).
    case basename
    /// Absolute path (`--full-path`).
    case fullPath
}

nonisolated enum OptionError: Error {
    case help
    case version
    case message(String)
}

nonisolated struct Options {
    static let programName = "drake"
    static let version = "1.0"

    var andExit = false
    var target = false
    var keep = false
    var printPath = false
    var all = false
    var allCompact = false
    var iconOnly = false
    var nameStyle: NameStyle = .relative
    var onTop = false
    var readStdin = false
    var thumbSize: CGFloat = 96
    var verbose = false
    /// Skip the window's opening animation (`--no-animation`).
    var noAnimation = false

    /// Show the history browser even though arguments were given (`--history`).
    var showHistory = false
    /// Skip recording this run (`--no-history`).
    var recordHistory = true

    /// Filenames and URIs left over after option parsing.
    var arguments: [String] = []

    /// `--all-compact` implies dragging everything at once.
    var dragAll: Bool { all || allCompact }

    /// With no files and no target, there is nothing to show but the history.
    var startsInHistory: Bool { showHistory || (arguments.isEmpty && !target) }

    static let usage = """
        \(programName) - drag-and-drop source/target with a history of past runs
        Usage: \(programName) [OPTION...] [FILE|URI...]
               \(programName)                  with no files, browse the history

          --and-exit,    -x  exit after a single completed drop
          --target,      -t  act as a target instead of source
          --keep,        -k  with --target, keep files to drag out
          --print-path,  -p  with --target, print file paths instead of URIs
          --all,         -a  drag all files at once
          --all-compact, -A  drag all files at once, only displaying the number of files
          --icon-only,   -i  only show icons in drag-and-drop windows
          --name-only,   -f  only show the file's basename and not the path
          --full-path,   -F  show the absolute path to all files
          --on-top,      -T  make window always-on-top
          --stdin,       -I  read filenames from stdin
          --thumb-size,  -s  set thumbnail size (default 96)
          --verbose,     -v  be verbose
          --history,     -H  browse the history of previous runs
          --no-history,  -N  do not record this run in the history
          --no-animation     open the window without the opening animation
          --help             show help
          --version          show version details
        """

    static func parse(_ argv: [String]) throws -> Options {
        var options = Options()
        var index = 0
        var optionsEnded = false

        while index < argv.count {
            let argument = argv[index]
            index += 1

            if optionsEnded || argument == "-" || !argument.hasPrefix("-") {
                options.arguments.append(argument)
                continue
            }
            if argument == "--" {
                optionsEnded = true
                continue
            }

            if argument.hasPrefix("--") {
                var name = String(argument.dropFirst(2))
                var inlineValue: String?
                if let equals = name.firstIndex(of: "=") {
                    inlineValue = String(name[name.index(after: equals)...])
                    name = String(name[..<equals])
                }
                try options.applyLong(name, inlineValue: inlineValue, argv: argv, index: &index)
            } else {
                try options.applyShort(argument, argv: argv, index: &index)
            }
        }

        return options
    }

    private mutating func applyLong(
        _ name: String,
        inlineValue: String?,
        argv: [String],
        index: inout Int
    ) throws {
        func value(for option: String) throws -> String {
            if let inlineValue { return inlineValue }
            guard index < argv.count else {
                throw OptionError.message("missing argument for `--\(option)'")
            }
            defer { index += 1 }
            return argv[index]
        }

        switch name {
        case "and-exit": andExit = true
        case "target": target = true
        case "keep": keep = true
        case "print-path": printPath = true
        case "all": all = true
        case "all-compact": allCompact = true
        case "icon-only": iconOnly = true
        case "name-only": nameStyle = .basename
        case "full-path": nameStyle = .fullPath
        case "on-top": onTop = true
        case "stdin": readStdin = true
        case "thumb-size": thumbSize = try Self.thumbSize(from: try value(for: name))
        case "verbose": verbose = true
        case "history": showHistory = true
        case "no-history": recordHistory = false
        case "no-animation": noAnimation = true
        case "help": throw OptionError.help
        case "version": throw OptionError.version
        default: throw OptionError.message("unknown option `--\(name)'")
        }
    }

    private mutating func applyShort(_ argument: String, argv: [String], index: inout Int) throws {
        let flags = Array(argument.dropFirst())
        var position = 0

        while position < flags.count {
            let flag = flags[position]
            position += 1

            switch flag {
            case "x": andExit = true
            case "t": target = true
            case "k": keep = true
            case "p": printPath = true
            case "a": all = true
            case "A": allCompact = true
            case "i": iconOnly = true
            case "f": nameStyle = .basename
            case "F": nameStyle = .fullPath
            case "T": onTop = true
            case "I": readStdin = true
            case "v": verbose = true
            case "H": showHistory = true
            case "N": recordHistory = false
            case "h": throw OptionError.help
            case "s":
                // Either the rest of this cluster (-s96) or the next argument (-s 96).
                let rest = String(flags[position...])
                if !rest.isEmpty {
                    position = flags.count
                    thumbSize = try Self.thumbSize(from: rest)
                } else {
                    guard index < argv.count else {
                        throw OptionError.message("missing argument for `-s'")
                    }
                    thumbSize = try Self.thumbSize(from: argv[index])
                    index += 1
                }
            default:
                throw OptionError.message("unknown option `-\(flag)'")
            }
        }
    }

    private static func thumbSize(from text: String) throws -> CGFloat {
        guard let size = Double(text), size >= 16, size <= 512 else {
            throw OptionError.message("bad thumbnail size `\(text)' (expected 16-512)")
        }
        return CGFloat(size)
    }

    /// Reads newline-separated filenames from standard input for `--stdin`.
    static func readLinesFromStandardInput() -> [String] {
        var lines: [String] = []
        while let line = readLine(strippingNewline: true) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { lines.append(trimmed) }
        }
        return lines
    }
}
