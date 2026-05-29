import SwiftUI
import PlyneCore
import PlyneStorage
import PlyneTimer

@main
struct PlyneApp: App {
    @State private var store: PlyneStore

    init() {
        _store = State(initialValue: PlyneApp.makeStore())
    }

    var body: some Scene {
        MenuBarExtra {
            TimerPopover()
                .environment(store)
        } label: {
            MenuBarLabel(progress: TimerProgress.make(for: store.state, now: store.displayNow))
        }
        .menuBarExtraStyle(.window)
    }

    /// Builds the live store. If the on-disk store can't be opened we fall back
    /// to an in-memory store and surface a calm notice rather than refusing to
    /// launch — the user can still run sessions this session.
    @MainActor
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
