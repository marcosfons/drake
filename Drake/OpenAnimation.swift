//
//  OpenAnimation.swift
//  Drake
//
//  The window scales up from slightly small while fading in. Kept well under
//  200ms so it never delays a drag.
//
//  Off by default: the window should appear the instant it is ready, and a
//  fade from transparent made opening feel ~160ms slower. Set `isEnabled`
//  below to true to bring it back; `--no-animation` then skips it per run.
//

import AppKit

@MainActor
enum OpenAnimation {
    /// Master switch. Off, so the window appears instantly.
    static let isEnabled = false

    static let duration: TimeInterval = 0.16
    /// Starting scale; the window grows from this to full size.
    static let initialScale: CGFloat = 0.92
    static let initialAlpha: CGFloat = 0.0

    /// Shows `window` with the opening animation, or plainly when disabled.
    static func show(_ window: NSWindow, animated: Bool) {
        guard isEnabled, animated, !isReducedMotionEnabled else {
            window.alphaValue = 1
            window.makeKeyAndOrderFront(nil)
            return
        }

        let finalFrame = window.frame
        window.alphaValue = initialAlpha
        window.setFrame(scaled(finalFrame, by: initialScale), display: false)
        window.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true
            window.animator().setFrame(finalFrame, display: true)
            window.animator().alphaValue = 1
        }
    }

    /// Respect the accessibility setting rather than animating regardless.
    static var isReducedMotionEnabled: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// Shrinks a frame towards its own centre.
    private static func scaled(_ frame: NSRect, by scale: CGFloat) -> NSRect {
        let width = frame.width * scale
        let height = frame.height * scale
        return NSRect(
            x: frame.midX - width / 2,
            y: frame.midY - height / 2,
            width: width,
            height: height
        )
    }
}
