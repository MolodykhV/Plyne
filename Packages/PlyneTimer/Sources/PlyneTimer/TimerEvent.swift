import Foundation
import PlyneCore

/// Inputs that drive the focus timer.
///
/// Every event that depends on the current time carries an explicit `now`
/// so the state machine stays a pure function of its inputs. The UI layer
/// (step 1.5) is responsible for sourcing `now` and emitting `tick`s.
public enum TimerEvent: Equatable, Sendable {
    /// Open the intention prompt for a chosen mode.
    case prepare(mode: SessionMode, intention: String?)

    /// Update the draft intention while preparing.
    case updateIntention(String?)

    /// Start the work phase.
    case start(now: Date)

    /// Back out of preparation without starting.
    case cancelPreparation

    /// Re-evaluate time-based transitions against `now`.
    case tick(now: Date)

    /// End the session normally. The end reason is derived from the state
    /// and timing (see ``FocusTimer/reduce(_:on:)``).
    case end(now: Date)

    /// Extend a main-ended Pomodoro by `minutes` (clamped to the allowed
    /// overflow range).
    case beginOverflow(now: Date, minutes: Int)

    /// End the session because something external cut it short.
    case interrupt(now: Date)

    /// Throw the in-flight session away without recording it.
    case discard

    /// Return to ``TimerState/idle`` from any state.
    case reset
}
