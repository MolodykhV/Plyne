import Foundation
import Testing
import PlyneCore
@testable import PlyneTimer

@Suite("FocusTimer lifecycle")
struct FocusTimerLifecycleTests {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    @Test
    func pomodoroHappyPathReachesMainEndedAtBell() {
        var state = FocusTimer.initialState
        state = FocusTimer.reduce(state, on: .prepare(mode: .pomodoro(workMinutes: 25, breakMinutes: 5), intention: "Write tests"))

        guard case let .preparing(mode, intention) = state else {
            Issue.record("expected preparing, got \(state)")
            return
        }
        #expect(mode == .pomodoro(workMinutes: 25, breakMinutes: 5))
        #expect(intention == "Write tests")

        state = FocusTimer.reduce(state, on: .start(now: start))
        #expect(state.isInFlight)
        #expect(state.activeSession?.startedAt == start)

        // A tick one minute in keeps it running.
        state = FocusTimer.reduce(state, on: .tick(now: start.addingTimeInterval(60)))
        if case .running = state {} else { Issue.record("expected running, got \(state)") }

        // A tick exactly at the bell flips to mainEnded.
        state = FocusTimer.reduce(state, on: .tick(now: start.addingTimeInterval(25 * 60)))
        if case .mainEnded = state {} else { Issue.record("expected mainEnded, got \(state)") }
    }

    @Test
    func finishingFromMainEndedUsesBellInstantAndCompletes() throws {
        let active = ActiveSession(mode: .pomodoro(workMinutes: 25, breakMinutes: 5), intention: nil, startedAt: start)
        let state = TimerState.mainEnded(active)

        // User dawdles 4 minutes past the bell before pressing finish.
        let finished = FocusTimer.reduce(state, on: .end(now: start.addingTimeInterval(29 * 60)))

        let session = try #require(finished.finishedSession)
        #expect(session.endReason == .completed)
        // Session ends at the bell (25 min), not when the button was pressed.
        let duration = try #require(session.duration)
        #expect(duration == 25 * 60)
    }

    @Test
    func flowmodoroNeverAutoEndsAndCompletesOnUserEnd() throws {
        var state = FocusTimer.initialState
        state = FocusTimer.reduce(state, on: .prepare(mode: .flowmodoro, intention: nil))
        state = FocusTimer.reduce(state, on: .start(now: start))

        // Even a tick eight hours later stays running.
        state = FocusTimer.reduce(state, on: .tick(now: start.addingTimeInterval(8 * 60 * 60)))
        if case .running = state {} else { Issue.record("flowmodoro should not auto-end") }

        state = FocusTimer.reduce(state, on: .end(now: start.addingTimeInterval(8 * 60 * 60)))
        let session = try #require(state.finishedSession)
        #expect(session.endReason == .completed)
        let duration = try #require(session.duration)
        #expect(duration == 8 * 60 * 60)
    }

    @Test
    func pomodoroEndedBeforeBellIsUserEnded() throws {
        var state = FocusTimer.initialState
        state = FocusTimer.reduce(state, on: .prepare(mode: .pomodoro(workMinutes: 25, breakMinutes: 5), intention: nil))
        state = FocusTimer.reduce(state, on: .start(now: start))

        state = FocusTimer.reduce(state, on: .end(now: start.addingTimeInterval(10 * 60)))
        let session = try #require(state.finishedSession)
        #expect(session.endReason == .userEnded)
        let duration = try #require(session.duration)
        #expect(duration == 10 * 60)
    }

    @Test
    func endingRunningPomodoroAtOrPastBellCompletesAtBell() throws {
        // Ending directly from `running` (no tick flipped to mainEnded) at or
        // past the bell must match the mainEnded path: completed, duration
        // pinned to the bell, independent of when the button was pressed.
        let active = ActiveSession(mode: .pomodoro(workMinutes: 25, breakMinutes: 5), intention: nil, startedAt: start)

        for offset in [25 * 60, 30 * 60] {
            let finished = FocusTimer.reduce(.running(active), on: .end(now: start.addingTimeInterval(TimeInterval(offset))))
            let session = try #require(finished.finishedSession)
            #expect(session.endReason == .completed)
            let duration = try #require(session.duration)
            #expect(duration == 25 * 60)
        }
    }

    @Test
    func cancelPreparationReturnsToIdle() {
        var state = FocusTimer.reduce(.idle, on: .prepare(mode: .flowmodoro, intention: "draft"))
        state = FocusTimer.reduce(state, on: .cancelPreparation)
        #expect(state == .idle)
    }

    @Test
    func updateIntentionKeepsModeAndReplacesText() {
        var state = FocusTimer.reduce(.idle, on: .prepare(mode: .flowmodoro, intention: "first"))
        state = FocusTimer.reduce(state, on: .updateIntention("second"))
        #expect(state == .preparing(mode: .flowmodoro, intention: "second"))
        state = FocusTimer.reduce(state, on: .updateIntention(nil))
        #expect(state == .preparing(mode: .flowmodoro, intention: nil))
    }

    @Test
    func producedSessionsAlwaysValidate() throws {
        // Walk a full pomodoro+overflow path and validate the result.
        var state = FocusTimer.initialState
        state = FocusTimer.reduce(state, on: .prepare(mode: .pomodoro(workMinutes: 25, breakMinutes: 5), intention: "x"))
        state = FocusTimer.reduce(state, on: .start(now: start))
        state = FocusTimer.reduce(state, on: .tick(now: start.addingTimeInterval(25 * 60)))
        state = FocusTimer.reduce(state, on: .beginOverflow(now: start.addingTimeInterval(25 * 60), minutes: 10))
        state = FocusTimer.reduce(state, on: .end(now: start.addingTimeInterval(34 * 60)))
        let session = try #require(state.finishedSession)
        try session.validate()
        #expect(session.endReason == .completed)
    }
}
