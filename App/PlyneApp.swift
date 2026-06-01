import SwiftUI
import PlyneCore
import PlyneStorage
import PlyneTimer

@main
struct PlyneApp: App {
    // The delegate owns the store, the dashboard, and the global-hotkey center,
    // and installs the hotkeys in applicationDidFinishLaunching — the reliable
    // launch hook for a menu-bar-only (LSUIElement) app.
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

/// App lifecycle owner: builds the single store + dashboard (sharing one
/// repository) and registers global hotkeys once the app has finished launching.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store: PlyneStore
    private let dashboard: DashboardWindowController
    private let onboarding = OnboardingWindowController(gate: OnboardingGate())
    private let hotkeys = GlobalHotkeyCenter()

    override init() {
        let repository = AppDelegate.makeRepository()
        let store = PlyneStore(repository: repository)
        self.store = store
        let model = DashboardModel(
            repository: repository,
            todaysBlocks: { [weak store] in store?.todaysBlocks ?? [] }
        )
        self.dashboard = DashboardWindowController(model: model)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // ⌃⌥⌘P start/stop, ⌃⌥⌘M switch mode, ⌃⌥⌘D open the dashboard. Each is
        // also reachable from the popover, so a chord the system refuses is not
        // fatal.
        hotkeys.register(HotkeyAction.toggleSession.defaultBinding) { [store] in
            store.toggleSession()
        }
        hotkeys.register(HotkeyAction.toggleMode.defaultBinding) { [store] in
            store.toggleDraftMode()
        }
        hotkeys.register(HotkeyAction.openDashboard.defaultBinding) { [dashboard] in
            dashboard.show()
        }
        // The popover's "Open dashboard" button routes through the same window.
        store.openDashboard = { [dashboard] in dashboard.show() }
        // The popover's "Welcome guide" re-opens the intro any time.
        store.openOnboarding = { [onboarding] in onboarding.show() }

        // First launch only: a calm three-screen intro (no-op afterwards).
        onboarding.showIfNeeded()
    }

    /// Builds the persistence repository. If the on-disk store can't be opened
    /// we fall back to an in-memory store and surface a calm notice rather than
    /// refusing to launch — the user can still run sessions this session.
    private static func makeRepository() -> any SessionRepository {
        if let repository = try? SwiftDataRepository.make() {
            return repository
        }
        // Last resort: an in-memory store so the app still runs. If even this
        // fails the app genuinely can't function, so the force is acceptable
        // here (and only here).
        // swiftlint:disable:next force_try
        return try! SwiftDataRepository.make(inMemory: true)
    }
}
