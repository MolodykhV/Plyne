import Foundation
import PlyneCore

/// The finite state of the focus timer.
///
/// All time-based transitions are driven by comparing an injected `now`
/// against instants stored in the state (e.g. the Pomodoro work end or the
/// overflow deadline). The machine never reads the wall clock itself, which
/// keeps it deterministic and survives sleep/wake and clock adjustments —
/// a tick simply re-evaluates against whatever `now` it is handed.
public enum TimerState: Equatable, Sendable {
    /// No session; ready to prepare one.
    case idle

    /// Intention prompt is up; mode chosen, nothing started yet.
    case preparing(mode: SessionMode, intention: String?)

    /// Work phase in progress.
    case running(ActiveSession)

    /// Pomodoro work phase reached its planned end; awaiting the user's
    /// choice to finish, take a break, or extend (overflow). Reached only
    /// by Pomodoro — Flowmodoro has no planned end.
    case mainEnded(ActiveSession)

    /// User chose to keep going past the bell. `until` is the soft deadline
    /// of the current overflow window; reaching it returns to ``mainEnded``
    /// (re-offering the choice) rather than force-finishing.
    case overflow(ActiveSession, until: Date)

    /// Terminal: produced a finished, validated session.
    case finished(Session)

    /// Terminal: the session was explicitly discarded; no session produced.
    case abandoned

    /// `true` while a session is in flight (running, main-ended, or overflow).
    public var isInFlight: Bool {
        switch self {
        case .running, .mainEnded, .overflow: return true
        case .idle, .preparing, .finished, .abandoned: return false
        }
    }

    /// The active session, if one is in flight.
    public var activeSession: ActiveSession? {
        switch self {
        case let .running(active), let .mainEnded(active), let .overflow(active, _):
            return active
        case .idle, .preparing, .finished, .abandoned:
            return nil
        }
    }

    /// The produced session, if the machine has finished.
    public var finishedSession: Session? {
        if case let .finished(session) = self { return session }
        return nil
    }
}
