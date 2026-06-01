import AppKit
import SwiftUI

/// Owns the single dashboard `NSWindow`, hosting the SwiftUI dashboard via
/// `NSHostingController`.
///
/// A menu-bar-only (LSUIElement) app can't rely on a SwiftUI `Window` scene
/// opened from outside the view tree (the global hotkey fires in the Carbon
/// handler), and accessory apps need explicit activation to come forward — so
/// the window is managed imperatively here and shown from both the popover and
/// the hotkey via `show()`.
@MainActor
final class DashboardWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let model: DashboardModel

    init(model: DashboardModel) {
        self.model = model
    }

    /// Shows the dashboard, reusing the existing window (single-instance) and
    /// bringing it to the front and key. A second invocation just re-fronts it.
    func show() {
        // Refresh on every open: a reused window keeps its view tree, so
        // SwiftUI's onAppear won't fire again — without this, reopening would
        // show data from the first open (missing sessions finished since).
        model.load()
        if let window {
            activateAndFront(window)
            return
        }
        // A headless, frosted-glass card (floating traffic lights, no title-bar
        // plate) so the dashboard reads as one Liquid-Glass surface, matching the
        // menu-bar popover and the approved design. The glass is the window's
        // contentView (installed in GlassWindow.host), so the view itself is
        // plain — no SwiftUI background needed.
        let root = DashboardView()
            .environment(model)
        let window = GlassWindow.makeHeadless(
            size: NSSize(width: 480, height: 620),
            resizable: true,
            title: String(localized: "dashboard.window.title"),
            delegate: self
        )
        GlassWindow.host(root, in: window)
        window.center()
        window.setContentSize(NSSize(width: 480, height: 620))
        self.window = window
        activateAndFront(window)
    }

    private func activateAndFront(_ window: NSWindow) {
        // Accessory apps don't take focus on makeKey alone; activate the app and
        // order front regardless so the window comes forward without flipping to
        // a Dock-showing (.regular) activation policy.
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    func windowWillClose(_ notification: Notification) {
        // Drop the reference so a later show() builds a fresh window; Cmd-W thus
        // closes the dashboard without quitting the menu-bar app.
        window = nil
    }
}
