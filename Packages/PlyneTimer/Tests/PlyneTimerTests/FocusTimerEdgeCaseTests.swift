import Foundation
import Testing
import PlyneCore
@testable import PlyneTimer

@Suite("FocusTimer edge cases")
struct FocusTimerEdgeCaseTests {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    @Test
    func interruptFromRunningProducesInterruptedSession() throws {
        var state = FocusTimer.reduce(.idle, on: .prepare(mode: .flowmodoro, intention: nil))
        state = FocusTimer.reduce(state, on: .start(now: start))
        state = FocusTimer.reduce(state, on: .interrupt(now: start.addingTimeInterval(300)))
        let session = try #require(state.finishedSession)
        #expect(session.endReason == .interrupted)
        let duration = try #require(session.duration)
        #expect(duration == 300)
    }

    @Test
    func interruptFromMainEndedCompletesAtBell() throws {
        let active = ActiveSession(mode: .pomodoro(workMinutes: 25, breakMinutes: 5), intention: nil, startedAt: start)
        let state = TimerState.mainEnded(active)
        let finished = FocusTimer.reduce(state, on: .interrupt(now: start.addingTimeInterval(40 * 60)))
        let session = try #require(finished.finishedSession)
        #expect(session.endReason == .interrupted)
        // Interruption after the bell still pins the work end to the bell.
        let duration = try #require(session.duration)
        #expect(duration == 25 * 60)
    }

    @Test
    func interruptFromOverflowEndsAtNow() throws {
        let active = ActiveSession(mode: .pomodoro(workMinutes: 25, breakMinutes: 5), intention: nil, startedAt: start)
        let bell = start.addingTimeInterval(25 * 60)
        var state = FocusTimer.reduce(.mainEnded(active), on: .beginOverflow(now: bell, minutes: 10))
        state = FocusTimer.reduce(state, on: .interrupt(now: bell.addingTimeInterval(6 * 60)))
        let session = try #require(state.finishedSession)
        #expect(session.endReason == .interrupted)
        // 25 min work + 6 min into overflow.
        let duration = try #require(session.duration)
        #expect(duration == 31 * 60)
    }

    @Test
    func discardProducesAbandonedWithNoSession() {
        var state = FocusTimer.reduce(.idle, on: .prepare(mode: .flowmodoro, intention: nil))
        state = FocusTimer.reduce(state, on: .start(now: start))
        state = FocusTimer.reduce(state, on: .discard)
        #expect(state == .abandoned)
        #expect(state.finishedSession == nil)
    }

    @Test
    func resetFromAnyStateReturnsToIdle() {
        let active = ActiveSession(mode: .flowmodoro, intention: nil, startedAt: start)
        let states: [TimerState] = [
            .idle,
            .preparing(mode: .flowmodoro, intention: "x"),
            .running(active),
            .mainEnded(active),
            .overflow(active, until: start.addingTimeInterval(600)),
            .finished(Session(startedAt: start, endedAt: start, mode: .flowmodoro, endReason: .completed)),
            .abandoned
        ]
        for state in states {
            #expect(FocusTimer.reduce(state, on: .reset) == .idle)
        }
    }

    @Test
    func clockSkewBackwardClampsToZeroDuration() throws {
        var state = FocusTimer.reduce(.idle, on: .prepare(mode: .flowmodoro, intention: nil))
        state = FocusTimer.reduce(state, on: .start(now: start))
        // Clock jumps backwards (e.g. NTP correction) — end is before start.
        state = FocusTimer.reduce(state, on: .end(now: start.addingTimeInterval(-120)))
        let session = try #require(state.finishedSession)
        // Clamped: endedAt == startedAt, zero duration, still valid.
        let duration = try #require(session.duration)
        #expect(duration == 0)
        try session.validate()
    }

    @Test
    func pomodoroAcrossMidnightUsesAbsoluteTimeNotCalendar() throws {
        // Start at 23:50, 25-minute pomodoro → bell at 00:15 the next day.
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 1
        components.hour = 23
        components.minute = 50
        let calendar = Calendar(identifier: .gregorian)
        let startedAt = try #require(calendar.date(from: components))

        var state = FocusTimer.reduce(.idle, on: .prepare(mode: .pomodoro(workMinutes: 25, breakMinutes: 5), intention: nil))
        state = FocusTimer.reduce(state, on: .start(now: startedAt))

        // 23:59 — still running.
        state = FocusTimer.reduce(state, on: .tick(now: startedAt.addingTimeInterval(9 * 60)))
        if case .running = state {} else { Issue.record("should still be running before the bell") }

        // 00:16 next day — past the bell.
        state = FocusTimer.reduce(state, on: .tick(now: startedAt.addingTimeInterval(26 * 60)))
        if case .mainEnded = state {} else { Issue.record("should have rung across midnight") }
    }

    @Test
    func invalidTransitionsAreNoOps() {
        // tick while idle, start while idle, end while idle, beginOverflow while running, etc.
        #expect(FocusTimer.reduce(.idle, on: .tick(now: start)) == .idle)
        #expect(FocusTimer.reduce(.idle, on: .end(now: start)) == .idle)
        #expect(FocusTimer.reduce(.idle, on: .start(now: start)) == .idle)

        let running = TimerState.running(ActiveSession(mode: .flowmodoro, intention: nil, startedAt: start))
        // Overflow only makes sense from mainEnded.
        #expect(FocusTimer.reduce(running, on: .beginOverflow(now: start, minutes: 10)) == running)
        // Can't prepare while running.
        #expect(FocusTimer.reduce(running, on: .prepare(mode: .flowmodoro, intention: nil)) == running)
    }

    @Test
    func longRunningFlowmodoroKeepsAccurateDuration() throws {
        var state = FocusTimer.reduce(.idle, on: .prepare(mode: .flowmodoro, intention: nil))
        state = FocusTimer.reduce(state, on: .start(now: start))
        // Several scattered ticks across an 8-hour day.
        for hour in 1...8 {
            state = FocusTimer.reduce(state, on: .tick(now: start.addingTimeInterval(TimeInterval(hour) * 3600)))
        }
        state = FocusTimer.reduce(state, on: .end(now: start.addingTimeInterval(8 * 3600)))
        let duration = try #require(state.finishedSession?.duration)
        #expect(duration == 8 * 3600)
    }
}
