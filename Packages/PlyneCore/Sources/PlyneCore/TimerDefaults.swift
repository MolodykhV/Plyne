import Foundation

/// Pomodoro defaults referenced by the timer FSM, the UI, and any future
/// onboarding flow.
public enum Pomodoro {
    /// Default work-phase length, in minutes (per concept doc, 25).
    public static let defaultWorkMinutes: Int = 25

    /// Default break-phase length, in minutes (per concept doc, 5).
    public static let defaultBreakMinutes: Int = 5
}

/// Helpers describing Plyne's Flowmodoro break rule.
public enum Flowmodoro {
    /// Hard cap on the recommended break length, in seconds (30 minutes).
    public static let maxBreakSeconds: TimeInterval = 30 * 60

    /// Ratio used to derive a break from a finished Flowmodoro work block.
    /// Concept-doc anchor: Kleitman's BRAC cycle (`recommendedBreak ≈
    /// workDuration / 5`), capped at ``maxBreakSeconds``.
    public static let workToBreakRatio: Double = 5.0

    /// Suggested break after a Flowmodoro session of the given length.
    public static func recommendedBreak(after workDuration: TimeInterval) -> TimeInterval {
        let proportional = (workDuration / workToBreakRatio).rounded(.down)
        return min(max(proportional, 0), maxBreakSeconds)
    }
}
