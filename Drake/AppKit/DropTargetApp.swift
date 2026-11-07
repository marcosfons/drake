//
//  DropTargetApp.swift
//  Drake
//
//  Which app a drag is heading for, so text files can be offered the way that
//  app accepts them: as a file URL (a path, for Terminal and editors) almost
//  everywhere, as an attachment copy (a file promise) over WhatsApp, which
//  refuses text files dragged as URLs. See DataFilePromise.
//
//  Read from the on-screen window list. Only owner PIDs, layers and bounds are
//  used, which need no screen-recording permission.
//

import AppKit

enum DropTargetApp {
    /// Apps that refuse a text file dragged as a file URL but accept it as an
    /// attachment.
    nonisolated static let attachmentApps: Set<String> = ["net.whatsapp.WhatsApp"]

    /// Switch this far outside an attachment app's window, so the drag is
    /// already rewritten when the app first inspects it at drag-enter.
    nonisolated static let margin: CGFloat = 40

    /// A normal window on screen, in window-list (top-left origin) coordinates.
    nonisolated struct Window {
        var bounds: CGRect
        var bundleID: String?
    }

    /// Whether a drag at `point` (AppKit screen coordinates) should offer
    /// attachments.
    @MainActor
    static func wantsAttachments(near point: NSPoint) -> Bool {
        wantsAttachments(at: windowListPoint(point), windows: windowsFrontToBack())
    }

    /// Walks windows front to back. An attachment app wins as soon as the point
    /// is within `margin` of one of its windows; any other window that actually
    /// covers the point hides whatever lies behind it.
    nonisolated static func wantsAttachments(at point: CGPoint, windows: [Window]) -> Bool {
        for window in windows {
            if let id = window.bundleID, attachmentApps.contains(id),
               window.bounds.insetBy(dx: -margin, dy: -margin).contains(point) {
                return true
            }
            if window.bounds.contains(point) { return false }
        }
        return false
    }

    /// AppKit's screen space has its origin at the bottom-left of the primary
    /// display; the window list's is at its top-left.
    @MainActor
    private static func windowListPoint(_ point: NSPoint) -> CGPoint {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGPoint(x: point.x, y: primaryHeight - point.y)
    }

    /// Other apps' normal (layer 0) on-screen windows, frontmost first.
    @MainActor
    private static func windowsFrontToBack() -> [Window] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        var bundleIDs: [pid_t: String?] = [:]

        return list.compactMap { info in
            guard (info[kCGWindowLayer as String] as? Int) == 0,
                  let pid = info[kCGWindowOwnerPID as String] as? pid_t, pid != ownPID,
                  let boundsInfo = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsInfo)
            else { return nil }
            if bundleIDs[pid] == nil {
                bundleIDs[pid] = .some(NSRunningApplication(processIdentifier: pid)?.bundleIdentifier)
            }
            return Window(bounds: bounds, bundleID: bundleIDs[pid] ?? nil)
        }
    }
}
