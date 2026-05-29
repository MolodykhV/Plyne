import Foundation
import PlyneCore

/// A view-agnostic description of how far the timer has advanced, derived
/// purely from a ``TimerState`` and the current instant.
///
/// Kept in `PlyneTimer` (not the UI layer) so it stays a pure, Linux-testable
/// function: the menu-bar icon and the popover both render from this rather
/// than reaching into the state's cases directly. Progress is always computed
/// from `now` versus the session's start — never accumulated — so it
/// self-corrects across sleep/wake and clock adjustments.
public struct TimerProgress: Equatable, Sendable {
    /// The visual phase the icon/UI should present. Distinct from
    /// ``TimerState`` because Flowmodoro (open-ended) and overflow want a
    /// different treatment than a plain running Pomodoro.
    public enum Phase: String, Sendable, CaseIterable {
        /// No session.
        case idle
        /// A Pomodoro work phase with a known endpoint.
        case running
        /// An open-ended Flowmodoro work phase (no endpoint to fill toward).
        case flowmodoro
        /// A Pomodoro that reached its bell, awaiting the user's choice.
        case mainEnded
        /// Continuing past the bell in an overflow window.
        case overflow
        /// A finished session, briefly summarized.
        case finished
    }

    /// The current phase.
    public let phase: Phase

    /// Completion of the current phase, clamped to `0...1`. Meaningful for
    /// ``Phase/running`` (Pomodoro fill); nominal `1` for `mainEnded`,
    /// `overflow`, and `finished`; `0` for `idle` and `flowmodoro` (which have
    /// no endpoint to fill toward — the icon shows a steady mark instead).
    public let fraction: Double

    /// Creates a progress value, clamping `fraction` into `0...1`.
    public init(phase: Phase, fraction: Double) {
        self.phase = phase
        self.fraction = min(max(fraction, 0), 1)
    }

    /// Derives the progress for `state` at instant `now`.
    public static func make(for state: TimerState, now: Date) -> TimerProgress {
        switch state {
        case .idle, .preparing, .abandoned:
            return TimerProgress(phase: .idle, fraction: 0)

        case let .running(active):
            guard let workEnd = active.pomodoroWorkEnd else {
                return TimerProgress(phase: .flowmodoro, fraction: 0)
            }
            let total = workEnd.timeIntervalSince(active.startedAt)
            guard total > 0 else { return TimerProgress(phase: .running, fraction: 1) }
            let elapsed = now.timeIntervalSince(active.startedAt)
            return TimerProgress(phase: .running, fraction: elapsed / total)

        case .mainEnded:
            return TimerProgress(phase: .mainEnded, fraction: 1)

        case .overflow:
            // Only the deadline is known, not the window's length, so the icon
            // shows a full ring plus a distinct mark rather than a fractional
            // arc. The popover renders the exact countdown to the deadline.
            return TimerProgress(phase: .overflow, fraction: 1)

        case .finished:
            return TimerProgress(phase: .finished, fraction: 1)
        }
    }
}
