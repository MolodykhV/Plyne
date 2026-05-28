import Foundation
import Testing
import PlyneCore
@testable import PlyneTimer

@Suite("FocusTimer overflow")
struct FocusTimerOverflowTests {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)
    private let bell: Date

    init() {
        bell = start.addingTimeInterval(25 * 60)
    }

    private func mainEndedPomodoro() -> TimerState {
        .mainEnded(ActiveSession(mode: .pomodoro(workMinutes: 25, breakMinutes: 5), intention: nil, startedAt: start))
    }

    @Test
    func beginOverflowClampsBelowMinimum() {
        let state = FocusTimer.reduce(mainEndedPomodoro(), on: .beginOverflow(now: bell, minutes: 1))
        guard case let .overflow(_, until) = state else {
            Issue.record("expected overflow, got \(state)")
            return
        }
        // 1 minute requested → clamped to the 5-minute floor.
        #expect(until == bell.addingTimeInterval(TimeInterval(Overflow.minMinutes) * 60))
    }

    @Test
    func beginOverflowClampsAboveMaximum() {
        let state = FocusTimer.reduce(mainEndedPomodoro(), on: .beginOverflow(now: bell, minutes: 60))
        guard case let .overflow(_, until) = state else {
            Issue.record("expected overflow, got \(state)")
            return
        }
        #expect(until == bell.addingTimeInterval(TimeInterval(Overflow.maxMinutes) * 60))
    }

    @Test
    func overflowTickWithinWindowStays() {
        var state = FocusTimer.reduce(mainEndedPomodoro(), on: .beginOverflow(now: bell, minutes: 10))
        state = FocusTimer.reduce(state, on: .tick(now: bell.addingTimeInterval(5 * 60)))
        if case .overflow = state {} else { Issue.record("expected overflow to persist, got \(state)") }
    }

    @Test
    func overflowReachingDeadlineReturnsToMainEndedNotFinished() {
        var state = FocusTimer.reduce(mainEndedPomodoro(), on: .beginOverflow(now: bell, minutes: 10))
        state = FocusTimer.reduce(state, on: .tick(now: bell.addingTimeInterval(10 * 60)))
        // Soft: returns to the decision point, does NOT force-finish.
        if case .mainEnded = state {} else { Issue.record("expected mainEnded re-decision, got \(state)") }
        #expect(state.finishedSession == nil)
    }

    @Test
    func finishingDuringOverflowCountsOverflowAsWork() throws {
        var state = FocusTimer.reduce(mainEndedPomodoro(), on: .beginOverflow(now: bell, minutes: 10))
        // Finish 8 minutes into the overflow.
        let endInstant = bell.addingTimeInterval(8 * 60)
        state = FocusTimer.reduce(state, on: .end(now: endInstant))
        let session = try #require(state.finishedSession)
        #expect(session.endReason == .completed)
        // Duration spans the full work + overflow (25 + 8 minutes).
        let duration = try #require(session.duration)
        #expect(duration == 33 * 60)
    }

    @Test
    func canExtendOverflowAgainAfterItElapses() {
        var state = FocusTimer.reduce(mainEndedPomodoro(), on: .beginOverflow(now: bell, minutes: 5))
        // First overflow window elapses → back to mainEnded.
        state = FocusTimer.reduce(state, on: .tick(now: bell.addingTimeInterval(5 * 60)))
        // Extend again.
        let secondStart = bell.addingTimeInterval(5 * 60)
        state = FocusTimer.reduce(state, on: .beginOverflow(now: secondStart, minutes: 5))
        guard case let .overflow(_, until) = state else {
            Issue.record("expected a second overflow window, got \(state)")
            return
        }
        #expect(until == secondStart.addingTimeInterval(5 * 60))
    }
}
