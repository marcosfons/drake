//
//  AppDelegate.swift
//  Drake
//
//  Builds the window by hand. Being launched from a shell rather than by Finder,
//  the app has to size, place and activate itself.
//

import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let options: Options
    private var model: AppModel?
    private var menuActions: MenuActions?
    private var window: NSWindow?
    private var titleObservation: NSObjectProtocol?

    init(options: Options) {
        self.options = options
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let history = HistoryStore()
        let model: AppModel
        do {
            model = try AppModel(options: options, history: history)
        } catch {
            FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
            exit(1)
        }
        self.model = model

        let actions = MenuActions(model: model)
        menuActions = actions
        NSApp.mainMenu = MainMenu.build(actions: actions)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: contentSize(for: model, width: nil)),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = model.windowTitle
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.contentView = NSHostingView(rootView: RootView().environment(model))
        // Bounded width: long paths get an ellipsis rather than the window
        // stretching to hold them.
        window.contentMinSize = NSSize(width: Metrics.minWidth, height: 120)
        window.contentMaxSize = NSSize(width: Metrics.maxWidth, height: .greatestFiniteMagnitude)
        window.setContentSize(contentSize(for: model, width: nil))
        window.center()

        if options.onTop {
            window.level = .floating
            window.collectionBehavior.insert(.canJoinAllSpaces)
        }

        self.window = window
        OpenAnimation.show(window, animated: !options.noAnimation)
        NSApp.activate(ignoringOtherApps: true)

        if options.verbose {
            model.log("Mode: \(model.mode), \(model.items.count) item(s)")
            // The settled size, not the frame mid-animation.
            let content = contentSize(for: model, width: nil)
            model.log("Content: \(Int(content.width))x\(Int(content.height)) pt"
                + " (width \(Int(Metrics.minWidth))-\(Int(Metrics.maxWidth)),"
                + " up to \(Metrics.maxVisibleRows) rows before scrolling)")
        }

        // Title and height follow the mode and item count, both of which change
        // when a history entry is opened or a drop is kept.
        startTrackingContent(model: model, window: window)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// Reopening from the Dock brings the single window back rather than nothing.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { window?.makeKeyAndOrderFront(nil) }
        return true
    }

    private func startTrackingContent(model: AppModel, window: NSWindow) {
        withObservationTracking {
            _ = model.mode
            _ = model.openedEntryTitle
            _ = model.items.count
        } onChange: {
            Task { @MainActor in
                window.title = model.windowTitle
                // Keep whatever width the user has chosen; only refit the height.
                window.setContentSize(
                    self.contentSize(for: model, width: window.contentLayoutRect.width)
                )
                self.startTrackingContent(model: model, window: window)
            }
        }
    }

    /// Content size for the current mode. Heights are exact: the list is as tall
    /// as its rows and only scrolls past `Metrics.maxVisibleRows`.
    private func contentSize(for model: AppModel, width existingWidth: CGFloat?) -> NSSize {
        let chrome = Metrics.footerHeight + Metrics.dividerHeight

        switch model.mode {
        case .history:
            let width = existingWidth ?? Metrics.historyWidth
            return NSSize(width: width, height: 520)

        case .target:
            let width = existingWidth ?? Metrics.targetWidth
            let dropZone: CGFloat = 140 + 24
            guard options.keep, !model.items.isEmpty else {
                return NSSize(width: width, height: dropZone + chrome)
            }
            let list = Metrics.visibleListHeight(rowCount: model.items.count, iconSize: 28)
            return NSSize(width: width, height: dropZone + Metrics.dividerHeight + list + chrome)

        case .source:
            let width = existingWidth ?? Metrics.sourceWidth
            if model.items.isEmpty {
                return NSSize(width: width, height: 160 + chrome)
            }
            if options.allCompact {
                return NSSize(width: width, height: 96 + chrome)
            }

            var height = chrome
            if options.dragAll {
                height += Metrics.dragAllTileHeight + Metrics.listPaddingVertical + Metrics.dragAllTileSpacing
            }
            if options.iconOnly {
                let rows = Metrics.gridRows(
                    count: model.items.count,
                    iconSize: options.thumbSize,
                    width: width
                )
                height += Metrics.visibleListHeight(
                    rowCount: min(rows, 4),
                    iconSize: options.thumbSize
                )
            } else {
                let iconSize = min(max(options.thumbSize / 3, 24), 64)
                height += Metrics.visibleListHeight(
                    rowCount: model.items.count,
                    iconSize: iconSize
                )
            }
            return NSSize(width: width, height: height)
        }
    }
}
