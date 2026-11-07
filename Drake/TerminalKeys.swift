//
//  TerminalKeys.swift
//  Drake
//
//  `q` typed in the terminal that launched drake closes it, just as `q` does
//  in the window, so there is no need to reach for Ctrl-C.
//
//  The terminal is switched to unbuffered, unechoed input for drake's
//  lifetime and restored on every way out: a normal exit (atexit), Ctrl-C,
//  SIGTERM and SIGHUP. Only done when standard input is a terminal and drake
//  is its foreground job, so `drake … &`, pipes and `--stdin` are untouched.
//

import AppKit
import Darwin

/// The terminal's settings before drake changed them, for restoring at exit.
/// Global so the C `atexit` callback can reach it without capturing.
nonisolated(unsafe) private var savedTerminal: termios?

nonisolated private func restoreTerminal() {
    guard var saved = savedTerminal else { return }
    tcsetattr(STDIN_FILENO, TCSANOW, &saved)
}

enum TerminalKeys {
    private static var input: DispatchSourceRead?
    private static var signals: [DispatchSourceSignal] = []

    /// Whether a chunk of terminal input asks to quit. Only a bare `q`/`Q`;
    /// Escape is left alone because arrow keys also start with it.
    nonisolated static func asksToQuit(_ bytes: some Sequence<UInt8>) -> Bool {
        bytes.contains { $0 == UInt8(ascii: "q") || $0 == UInt8(ascii: "Q") }
    }

    static func start(onQuit: @escaping @MainActor () -> Void) {
        let fd = STDIN_FILENO
        guard input == nil, isatty(fd) == 1, tcgetpgrp(fd) == getpgrp() else { return }

        var original = termios()
        guard tcgetattr(fd, &original) == 0 else { return }
        var keys = original
        // Byte at a time, not echoed. ISIG stays on, so Ctrl-C still works.
        keys.c_lflag &= ~tcflag_t(ICANON | ECHO)
        withUnsafeMutableBytes(of: &keys.c_cc) { cc in
            cc[Int(VMIN)] = 1
            cc[Int(VTIME)] = 0
        }
        savedTerminal = original
        guard tcsetattr(fd, TCSANOW, &keys) == 0 else {
            savedTerminal = nil
            return
        }
        atexit { restoreTerminal() }

        // Signals that would otherwise kill drake before atexit runs: restore
        // the terminal, then die of the same signal as before.
        for number in [SIGINT, SIGTERM, SIGHUP] {
            signal(number, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: number, queue: .main)
            source.setEventHandler {
                restoreTerminal()
                signal(number, SIG_DFL)
                raise(number)
            }
            source.resume()
            signals.append(source)
        }
        // If drake is later put in the background, reading fails instead of
        // stopping the process; the read source then simply ends.
        signal(SIGTTIN, SIG_IGN)

        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .main)
        source.setEventHandler {
            var buffer = [UInt8](repeating: 0, count: 64)
            let count = read(fd, &buffer, buffer.count)
            guard count > 0 else {
                source.cancel()
                return
            }
            if asksToQuit(buffer[..<count]) {
                MainActor.assumeIsolated { onQuit() }
            }
        }
        source.resume()
        input = source
    }
}
