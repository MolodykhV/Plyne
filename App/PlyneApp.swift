import SwiftUI
import PlyneCore
import PlyneStorage
import PlyneTimer

@main
struct PlyneApp: App {
    // The delegate owns the store and the global-hotkey center, and installs
    // the hotkeys in applicationDidFinishLaunching — the reliable launch hook
    // for a menu-bar-only (LSUIElement) app.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            TimerPopover()
                .environment(delegate.store)
        } label: {
            MenuBarLabel(progress: TimerProgress.make(for: delegate.store.state, now: delegate.store.displayNow))
        }
        .menuBarExtraStyle(.window)
    }
}

/// App lifecycle owner: builds the single store and registers global hotkeys
/// once the app has finished launching.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = AppDelegate.makeStore()
    private let hotkeys = GlobalHotkeyCenter()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // ⌃⌥⌘P start/stop, ⌃⌥⌘M switch mode. Each action is also reachable
        // from the popover, so a registration the system refuses is not fatal.
        hotkeys.register(HotkeyAction.toggleSession.defaultBinding) { [store] in
            store.toggleSession()
        }
        hotkeys.register(HotkeyAction.toggleMode.defaultBinding) { [store] in
            store.toggleDraftMode()
        }
    }

    /// Builds the live store. If the on-disk store can't be opened we fall back
    /// to an in-memory store and surface a calm notice rather than refusing to
    /// launch — the user can still run sessions this session.
    private static func makeStore() -> PlyneStore {
        if let repository = try? SwiftDataRepository.make() {
            return PlyneStore(repository: repository)
        }
        // Last resort: an in-memory store so the app still runs. If even this
        // fails the app genuinely can't function, so the force is acceptable
        // here (and only here).
        // swiftlint:disable:next force_try
        return PlyneStore(repository: try! SwiftDataRepository.make(inMemory: true))
    }
}
