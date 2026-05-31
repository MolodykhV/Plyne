import Foundation

/// Remembers whether the first-run onboarding has been seen.
///
/// One-shot and forgiving: once the window has been shown and dismissed — by
/// finishing it or simply closing it — it never reappears. Plyne does not nag a
/// user back into an intro they have already left. `UserDefaults` is injected so
/// the gate stays testable and free of shared mutable state.
struct OnboardingGate {
    private let defaults: UserDefaults
    private let key = "app.plyne.onboarding.completed"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// `true` once onboarding has been seen.
    var hasCompleted: Bool { defaults.bool(forKey: key) }

    /// Marks onboarding as seen so it won't be shown again.
    func markCompleted() { defaults.set(true, forKey: key) }
}
