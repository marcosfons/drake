//
//  AppDelegate.swift
//  Drake
//
//  Builds the window by hand. Being launched from a shell rather than by Finder,
//  the app has to size, place and activate itself. The delegate is also the
//  end of the responder chain, where the menu commands land (MainMenu.swift).
//

import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    let model: AppModel
    let toolbar: WindowToolbar
    private(set) var window: DrakeWindow?

    init(model: AppModel) {
        self.model = model
        self.toolbar = WindowToolbar(model: model)
        super.init()
    }

    private var options: Options { model.options }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Always dark, menus and panels included. Drake is a small utility
        // window that sits over other apps, where a dark surface reads best.
        NSApp.appearance = NSAppearance(named: .darkAqua)
        NSApp.mainMenu = MainMenu.build()

        let window = makeWindow()
        self.window = window
        window.makeKeyAndOrderFront(nil)
        // Launched from a terminal, which stays frontmost unless drake takes
        // over; cooperative activation would leave the window behind it.
        NSApp.activate(ignoringOtherApps: true)
        TerminalKeys.start { NSApp.terminate(nil) }

        let size = contentSize(width: nil)
        Log.app.info("Mode: \(model.mode), \(model.items.count) item(s)")
        // The settled size, from Metrics, not the frame mid-animation.
        Log.app.info("Content: \(Int(size.width))x\(Int(size.height)) pt"
            + " (width \(Int(Metrics.minWidth))-\(Int(Metrics.maxWidth)),"
            + " up to \(Metrics.maxVisibleRows) rows before scrolling)")

        observeModel(window: window)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// Files may have been moved or deleted while drake was in the background.
    func applicationDidBecomeActive(_ notification: Notification) {
        FileInfoCache.shared.invalidate()
    }

    /// Reopening from the Dock brings the single window back rather than nothing.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { window?.makeKeyAndOrderFront(nil) }
        return true
    }

    // MARK: - Window

    private func makeWindow() -> DrakeWindow {
        let size = contentSize(width: nil)
        let window = DrakeWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = model.windowTitle
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.toolbar = toolbar.toolbar
        window.toolbarStyle = .unifiedCompact
        window.backgroundColor = Palette.nsBackground
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        // The system's own window-opening animation; it never delays the window.
        window.animationBehavior = options.noAnimation ? .none : .documentWindow

        let hostingView = NSHostingView(rootView: RootView().environment(model))
        // The window is sized from Metrics; SwiftUI must not resize it after
        // its first layout pass, or it opens at one height and jumps to another.
        hostingView.sizingOptions = []
        window.contentView = hostingView

        // Bounded width: long paths are shortened rather than the window
        // stretching to hold them. No taller minimum than a single row.
        window.contentMinSize = NSSize(width: Metrics.minWidth, height: Metrics.minContentHeight)
        window.contentMaxSize = NSSize(width: Metrics.maxWidth, height: .greatestFiniteMagnitude)
        window.setContentSize(size)
        window.center()

        // Follow the user across Spaces: drake is often launched from a
        // terminal on one desktop and dropped into an app on another.
        // fullScreenAuxiliary lets it also appear over full-screen apps.
        // The edge flicker during the Space-switch slide is macOS's own: any
        // app assigned to All Desktops shows it. Floating, .stationary, no
        // shadow and moving the window after the switch were all tried; none
        // helped, and moving it left it blinking and minimised.
        window.collectionBehavior.formUnion([.canJoinAllSpaces, .fullScreenAuxiliary])
        if options.onTop {
            window.level = .floating
        }
        window.installCloseKeys()
        return window
    }

    private func contentSize(width: CGFloat?) -> CGSize {
        Metrics.contentSize(mode: model.mode, itemCount: model.items.count, options: options, width: width)
    }

    /// Title, toolbar and height follow the model. The height refits only when
    /// the mode or the item count changes, keeping the user's width, so a
    /// selection change never undoes a manual resize.
    private func observeModel(window: NSWindow) {
        let model = model
        let toolbar = toolbar

        Task {
            for await title in Observations({ @MainActor in model.windowTitle }) {
                window.title = title
            }
        }
        Task {
            for await _ in Observations({ @MainActor in
                ToolbarState(mode: model.mode, canGoBack: model.canGoBackToHistory, canReturn: model.canReturnFromHistory)
            }) {
                toolbar.update()
            }
        }
        Task { [weak self] in
            var previous: LayoutState?
            for await layout in Observations({ @MainActor in
                LayoutState(mode: model.mode, itemCount: model.items.count)
            }) {
                defer { previous = layout }
                guard let previous, previous != layout, let self else { continue }
                window.setContentSize(self.contentSize(width: window.contentLayoutRect.width))
            }
        }
    }

    private struct ToolbarState: Equatable, Sendable {
        let mode: AppModel.Mode
        let canGoBack: Bool
        let canReturn: Bool
    }

    private struct LayoutState: Equatable, Sendable {
        let mode: AppModel.Mode
        let itemCount: Int
    }
}
