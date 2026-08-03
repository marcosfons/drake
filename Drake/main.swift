//
//  main.swift
//  Drake
//
//  Entry point. Options are parsed before AppKit starts so --help, --version and
//  bad arguments behave like a normal command-line tool.
//

import AppKit

/// Keeps the delegate alive for the lifetime of the process.
nonisolated(unsafe) var retainedDelegate: AppDelegate?

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

/// Under XCTest the host app is launched with the harness's own arguments, which
/// are none of our business.
let launchArguments: [String] = {
    let environment = ProcessInfo.processInfo.environment
    if environment["XCTestConfigurationFilePath"] != nil || environment["XCTestBundlePath"] != nil {
        return []
    }
    // Finder passes a process serial number; ignore it and anything else the
    // system prepends.
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

if options.readStdin {
    options.arguments.append(contentsOf: Options.readLinesFromStandardInput())
}

MainActor.assumeIsolated {
    let application = NSApplication.shared
    let delegate = AppDelegate(options: options)
    // NSApplication only holds a weak reference to its delegate.
    retainedDelegate = delegate
    application.delegate = delegate
    application.setActivationPolicy(.regular)
    application.run()
}
