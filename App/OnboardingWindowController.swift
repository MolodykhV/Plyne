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
    /// seen.
    func showIfNeeded() {
        guard !gate.hasCompleted else { return }
        // Mark seen the moment we present it: by design any presentation counts
        // as "seen", and writing here (not only on close) survives a Cmd-Q while
        // the window is open — windowWillClose is not delivered on app terminate.
        gate.markCompleted()
        let root = OnboardingView(onDone: { [weak self] in self?.window?.close() })
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 430),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = String(localized: "onboarding.window.title")
        window.contentViewController = NSHostingController(rootView: root)
        window.isReleasedWhenClosed = false  // we hold the reference; release on close
        window.delegate = self
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
