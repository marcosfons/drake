//
//  main.swift
//  Drake
//
//  Entry point. Options are parsed and the files checked before AppKit starts,
//  so --help, --version, bad arguments and missing files behave like a normal
//  command-line tool: a message on stderr and an exit code, no Dock icon.
//

import AppKit

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

/// Under XCTest the host app is launched with the harness's own arguments,
/// which are none of drake's business.
let launchArguments: [String] = {
    let environment = ProcessInfo.processInfo.environment
    if environment["XCTestConfigurationFilePath"] != nil || environment["XCTestBundlePath"] != nil {
        return []
    }
    // Finder passes a process serial number; ignore it.
    return CommandLine.arguments.dropFirst().filter { !$0.hasPrefix("-psn_") }
}()

var options: Options
do {
    options = try Options.parse(launchArguments)
} catch OptionError.help {
    print(Options.usage)
    exit(0)
} catch OptionError.version {
    print("\(Options.programName) \(Options.version)")
    exit(0)
} catch let OptionError.message(message) {
    fail("""
        \(Options.programName): error: \(message)
        Try `\(Options.programName) --help' for more information.
        """)
} catch {
    fail("\(Options.programName): error: \(error.localizedDescription)")
}

Log.echoesToStandardError = options.verbose

if options.readStdin {
    options.arguments.append(contentsOf: Options.readLinesFromStandardInput())
}

let model: AppModel
do {
    model = try AppModel(options: options, history: HistoryStore())
} catch {
    fail("\(Options.programName): \(error.localizedDescription)")
}

let application = NSApplication.shared
let delegate = AppDelegate(model: model)
application.delegate = delegate
application.setActivationPolicy(.regular)
// NSApplication holds its delegate weakly; run() never returns.
withExtendedLifetime(delegate) {
    application.run()
}
