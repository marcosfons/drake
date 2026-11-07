//
//  MarqueeSelection.swift
//  Drake
//
//  Rubber-band selection: press in empty space and sweep, the way selecting text
//  or Finder icons works. The view sits on top of the whole list but reports
//  itself as "not hit" wherever a row is, so presses on a row still start a file
//  drag and only the gaps, the padding and the space below the last row sweep.
//

import AppKit
import SwiftUI

/// The list's latest scroll offset, held by reference: the scroll view writes
/// it on every frame and the overlay reads it only when the mouse is pressed.
/// Kept out of SwiftUI state so scrolling does not re-render every row.
final class ScrollOffsetBox {
    var value: CGFloat = 0
}

final class MarqueeSelectionNSView: NSView {
    /// Row geometry, so the view knows which points belong to a row.
    var rowCount: Int = 0
    var rowHeight: CGFloat = 42
    var rowSpacing: CGFloat = 4
    var topInset: CGFloat = 10
    var scrollOffsetBox = ScrollOffsetBox()
    var scrollOffset: CGFloat { scrollOffsetBox.value }

    /// Called when a sweep starts; `false` means the selection should be reset.
    var onBegin: (Bool) -> Void = { _ in }
    /// Called continuously with the swept rectangle in this view's coordinates.
    var onSweep: (CGRect, Bool) -> Void = { _, _ in }
    var onEnd: () -> Void = {}

    private var anchor: CGPoint?
    private var cursor: CGPoint?
    private var isAdditive = false

    /// Top-left origin, matching the order rows are laid out in.
    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    /// Rows keep their own press handling; everything else sweeps.
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let local = superview.map({ convert(point, from: $0) }), bounds.contains(local) else {
            return nil
        }
        return isOverRow(local) ? nil : self
    }

    private func isOverRow(_ point: CGPoint) -> Bool {
        guard rowCount > 0 else { return false }
        let step = rowHeight + rowSpacing
        let y = point.y + scrollOffset - topInset
        guard y >= 0 else { return false }
        let index = Int(y / step)
        guard index < rowCount else { return false }
        // Inside the row itself, not in the gap that follows it.
        return y - CGFloat(index) * step <= rowHeight
    }

    /// Indices of the rows a swept rectangle touches vertically.
    func rowIndices(in rect: CGRect) -> [Int] {
        guard rowCount > 0 else { return [] }
        let step = rowHeight + rowSpacing
        let top = rect.minY + scrollOffset - topInset
        let bottom = rect.maxY + scrollOffset - topInset
        return (0..<rowCount).filter { index in
            let rowTop = CGFloat(index) * step
            return bottom > rowTop && top < rowTop + rowHeight
        }
    }

    // MARK: - Tracking

    override func mouseDown(with event: NSEvent) {
        anchor = convert(event.locationInWindow, from: nil)
        cursor = nil
        isAdditive = event.modifierFlags.contains(.command) || event.modifierFlags.contains(.shift)
        onBegin(isAdditive)
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let anchor else { return }
        let point = convert(event.locationInWindow, from: nil)
        cursor = point
        needsDisplay = true
        onSweep(Self.rect(from: anchor, to: point), isAdditive)
        autoscroll(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        anchor = nil
        cursor = nil
        needsDisplay = true
        onEnd()
    }

    /// Scrolling stays with the list underneath. The overlay is a sibling layer
    /// above the scroll view, not inside it, so the responder chain leads away
    /// from the list - the scroll view has to be found and fed directly.
    override func scrollWheel(with event: NSEvent) {
        if let scrollView = Self.scrollView(under: event) {
            scrollView.scrollWheel(with: event)
        } else {
            nextResponder?.scrollWheel(with: event)
        }
    }

    /// Deepest scroll view in the window under the event's location.
    static func scrollView(under event: NSEvent) -> NSScrollView? {
        guard let root = event.window?.contentView else { return nil }
        let point = event.locationInWindow

        func search(_ view: NSView) -> NSScrollView? {
            guard !view.isHidden, view.bounds.contains(view.convert(point, from: nil)) else {
                return nil
            }
            for subview in view.subviews.reversed() {
                if let found = search(subview) { return found }
            }
            return view as? NSScrollView
        }

        return search(root)
    }

    private static func rect(from a: CGPoint, to b: CGPoint) -> CGRect {
        CGRect(
            x: min(a.x, b.x),
            y: min(a.y, b.y),
            width: abs(a.x - b.x),
            height: abs(a.y - b.y)
        )
    }

    private var selectionRect: CGRect? {
        guard let anchor, let cursor else { return nil }
        let rect = Self.rect(from: anchor, to: cursor)
        guard rect.width > 1 || rect.height > 1 else { return nil }
        return rect
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let selectionRect else { return }
        let path = NSBezierPath(rect: selectionRect)
        NSColor.controlAccentColor.withAlphaComponent(0.18).setFill()
        path.fill()
        NSColor.controlAccentColor.withAlphaComponent(0.75).setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}

struct MarqueeSelectionOverlay: NSViewRepresentable {
    var rowCount: Int
    var rowHeight: CGFloat
    var rowSpacing: CGFloat = Metrics.rowSpacing
    var topInset: CGFloat = Metrics.listPaddingVertical
    var scrollOffset: ScrollOffsetBox

    var onBegin: (Bool) -> Void
    /// Receives the indices of the rows the sweep currently covers.
    var onSweep: ([Int], Bool) -> Void
    var onEnd: () -> Void = {}

    func makeNSView(context: Context) -> MarqueeSelectionNSView {
        let view = MarqueeSelectionNSView()
        apply(to: view)
        return view
    }

    func updateNSView(_ view: MarqueeSelectionNSView, context: Context) {
        apply(to: view)
    }

    private func apply(to view: MarqueeSelectionNSView) {
        view.rowCount = rowCount
        view.rowHeight = rowHeight
        view.rowSpacing = rowSpacing
        view.topInset = topInset
        view.scrollOffsetBox = scrollOffset
        view.onBegin = onBegin
        view.onSweep = { [weak view] rect, additive in
            guard let view else { return }
            onSweep(view.rowIndices(in: rect), additive)
        }
        view.onEnd = onEnd
    }
}
