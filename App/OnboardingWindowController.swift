import AppKit
import SwiftUI

/// Owns the single first-run onboarding `NSWindow`, hosting `OnboardingView`.
///
/// Like the dashboard, this is managed imperatively rather than as a SwiftUI
/// `Window` scene: a menu-bar-only (LSUIElement) app shows it from
/// `applicationDidFinishLaunching` (outside the view tree) and, as an accessory
/// app, must activate explicitly to bring the window forward.
@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let gate: OnboardingGate

    init(gate: OnboardingGate) {
        self.gate = gate
    }

    /// Shows the onboarding window on first run only; a no-op once it has been
    /// seen. Marking seen here (not only on close) survives a Cmd-Q while the
    /// window is open — windowWillClose is not delivered on app terminate.
    func showIfNeeded() {
        guard !gate.hasCompleted else { return }
        gate.markCompleted()
        show()
    }

    /// Presents the onboarding intro on demand (the popover's "Welcome guide"),
    /// reusing the existing window if it's already open (single-instance).
    func show() {
        if let window {
            activateAndFront(window)
            return
        }
        // A headless, frosted-glass card (floating traffic lights, no title-bar
        // plate) — reads as one calm Liquid-Glass surface, matching the popover.
        let root = OnboardingView(onDone: { [weak self] in self?.window?.close() })
        let window = GlassWindow.makeHeadless(
            size: NSSize(width: 460, height: 430),
            resizable: false,
            title: String(localized: "onboarding.window.title"),
            delegate: self
        )
        GlassWindow.host(root, in: window)
        window.center()
        self.window = window
        activateAndFront(window)
    }

    private func activateAndFront(_ window: NSWindow) {
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    func windowWillClose(_ notification: Notification) {
        // The seen-flag is already set in showIfNeeded(); just drop the
        // reference so the window can be released.
        window = nil
    }
}
