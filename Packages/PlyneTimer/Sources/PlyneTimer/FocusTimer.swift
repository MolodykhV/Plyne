import Foundation
import PlyneCore

/// The focus-timer state machine.
///
/// `FocusTimer` is a pure reducer: `reduce(state, on: event)` returns the
/// next state and nothing else. There is no internal clock, no scheduling,
/// and no side effects — the caller drives time by handing in `now` on the
/// relevant events. Invalid transitions are no-ops (the state is returned
/// unchanged) so a UI can send events freely without guarding every case.
public enum FocusTimer {
    /// The starting state.
    public static let initialState: TimerState = .idle

    // The transition table is one flat `switch` over (state, event). Its
    // cyclomatic complexity is high by the linter's count, but each arm is
    // trivial and the exhaustive switch is exactly what makes the machine
    // auditable — splitting it would hurt readability, so the rule is
    // disabled around it deliberately.
    // swiftlint:disable cyclomatic_complexity
    /// Applies `event` to `state` and returns the next state.
    public static func reduce(_ state: TimerState, on event: TimerEvent) -> TimerState {
        switch (state, event) {

        // Reset is always available.
        case (_, .reset):
            return .idle

        // idle → preparing
        case let (.idle, .prepare(mode, intention)):
            return .preparing(mode: mode, intention: intention)

        // preparing
        case let (.preparing(mode, _), .updateIntention(intention)):
            return .preparing(mode: mode, intention: intention)

        case let (.preparing(mode, intention), .start(now)):
            return .running(ActiveSession(mode: mode, intention: intention, startedAt: now))

        case (.preparing, .cancelPreparation):
            return .idle

        // running
        case let (.running(active), .tick(now)):
            if let workEnd = active.pomodoroWorkEnd, now >= workEnd {
                return .mainEnded(active)
            }
            return state

        case let (.running(active), .end(now)):
            if let workEnd = active.pomodoroWorkEnd, now >= workEnd {
                // Past the bell but no tick flipped us to mainEnded yet —
                // finish identically to the mainEnded path (end at the bell,
                // completed), so the recorded duration doesn't depend on tick
                // cadence.
                return .finished(makeSession(active, endedAt: workEnd, reason: .completed))
            }
            // Pomodoro stopped before the bell is ended-early; an open-ended
            // Flowmodoro stop is its natural completion (no judgmental frame).
            let reason: SessionEndReason = active.isPomodoro ? .userEnded : .completed
            return .finished(makeSession(active, endedAt: now, reason: reason))

        case let (.running(active), .interrupt(now)):
            return .finished(makeSession(active, endedAt: now, reason: .interrupted))

        case (.running, .discard):
            return .abandoned

        // mainEnded (Pomodoro only). The bell already rang, so the work end
        // — not the time the user got around to pressing a button — is the
        // session end.
        case let (.mainEnded(active), .end):
            return .finished(makeSession(active, endedAt: bellInstant(active), reason: .completed))

        case let (.mainEnded(active), .beginOverflow(now, minutes)):
            let until = now.addingTimeInterval(TimeInterval(Overflow.clampedMinutes(minutes)) * 60)
            return .overflow(active, until: until)

        case let (.mainEnded(active), .interrupt):
            return .finished(makeSession(active, endedAt: bellInstant(active), reason: .interrupted))

        case (.mainEnded, .discard):
            return .abandoned

        // overflow. Reaching the window's end re-offers the choice rather
        // than force-finishing (concept: "без насильственного завершения").
        case let (.overflow(active, until), .tick(now)):
            if now >= until {
                return .mainEnded(active)
            }
            return state

        case let (.overflow(active, _), .end(now)):
            return .finished(makeSession(active, endedAt: now, reason: .completed))

        case let (.overflow(active, _), .interrupt(now)):
            return .finished(makeSession(active, endedAt: now, reason: .interrupted))

        case (.overflow, .discard):
            return .abandoned

        // Everything else is an invalid transition for the current state.
        default:
            return state
        }
    }
    // swiftlint:enable cyclomatic_complexity

    /// Builds a session entered after the fact, bypassing the live machine.
    ///
    /// Used by the retroactive-entry flow. The result is validated, so this
    /// throws ``PlyneCore/DomainError`` on a reversed interval or invalid
    /// mode parameters.
    public static func retroactiveSession(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        mode: SessionMode,
        intention: String? = nil,
        categoryHint: String? = nil
    ) throws -> Session {
        let session = Session(
            id: id,
            startedAt: startedAt,
            endedAt: endedAt,
            mode: mode,
            intention: intention,
            categoryHint: categoryHint,
            endReason: .retroactive
        )
        try session.validate()
        return session
    }

    // MARK: - Helpers

    /// The Pomodoro bell instant, falling back to the start for non-Pomodoro
    /// modes (which never reach `mainEnded`, so the fallback is unused in
    /// practice).
    private static func bellInstant(_ active: ActiveSession) -> Date {
        active.pomodoroWorkEnd ?? active.startedAt
    }

    /// Materializes a validated-by-construction `Session`. `endedAt` is
    /// clamped to be no earlier than `startedAt` to absorb backward clock
    /// jumps (sleep/wake, NTP) without producing an invalid value.
    private static func makeSession(
        _ active: ActiveSession,
        endedAt: Date,
        reason: SessionEndReason
    ) -> Session {
        Session(
            id: active.id,
            startedAt: active.startedAt,
            endedAt: max(endedAt, active.startedAt),
            mode: active.mode,
            intention: active.intention,
            categoryHint: nil,
            endReason: reason
        )
    }
}
