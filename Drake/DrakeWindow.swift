//
//  DrakeWindow.swift
//  Drake
//
//  Escape closes the window.
//
//  This is done with a local event monitor rather than a SwiftUI keyboard
//  shortcut or a responder-chain override, because neither is reliable here:
//  SwiftUI's focus handling and the AppKit drag and sweep overlays both sit in
//  front of the window in the responder chain and can swallow the key. A local
//  monitor sees the event before it is dispatched at all.
//

import AppKit

final class DrakeWindow: NSWindow {
    private var escapeMonitor: Any?

    /// Starts watching for the close keys. Safe to call once the window exists.
    func installEscapeToClose() {
        guard escapeMonitor == nil else { return }
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self else { return event }
            return self.handle(event)
        }
    }

    /// Returns nil to swallow the key, or the event to let it through.
    private func handle(_ event: NSEvent) -> NSEvent? {
        let escape: UInt16 = 53
        let isEscape = event.keyCode == escape
        let isQ = event.charactersIgnoringModifiers?.lowercased() == "q" && isUnmodified(event)

        guard isEscape || isQ else { return event }

        // Typing wins over closing: "q" has to reach the history search field,
        // and there Escape leaves the field first, closing on a second press.
        if isEditingText {
            if isEscape {
                makeFirstResponder(nil)
                return nil
            }
            return event
        }

        NSApp.terminate(nil)
        return nil
    }

    /// True when no modifier that would mean something else is held, so ⌘Q and
    /// ⌃Q still take their usual paths.
    private func isUnmodified(_ event: NSEvent) -> Bool {
        let meaningful: NSEvent.ModifierFlags = [.command, .control, .option, .shift]
        return event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .intersection(meaningful)
            .isEmpty
    }

    isolated deinit {
        if let escapeMonitor {
            NSEvent.removeMonitor(escapeMonitor)
        }
    }

    /// Also handles Escape and ⌘. when they do arrive through the chain.
    override func cancelOperation(_ sender: Any?) {
        if isEditingText {
            makeFirstResponder(nil)
            return
        }
        NSApp.terminate(sender)
    }

    private var isEditingText: Bool {
        guard let responder = firstResponder else { return false }
        if let textView = responder as? NSTextView {
            return textView.isFieldEditor || textView.isEditable
        }
        return responder is NSTextField || responder is NSSearchField
    }
}
