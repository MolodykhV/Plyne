import Foundation
import Testing
import PlyneCore
@testable import PlyneTimer

@Suite("TimerProgress")
struct TimerProgressTests {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    @Test
    func idleStates() {
        for state in [TimerState.idle, .preparing(mode: .flowmodoro, intention: nil), .abandoned] {
            let progress = TimerProgress.make(for: state, now: start)
            #expect(progress.phase == .idle)
            #expect(progress.fraction == 0)
        }
    }

    @Test
    func runningPomodoroFillsLinearly() {
        let active = ActiveSession(mode: .pomodoro(workMinutes: 20, breakMinutes: 5), intention: nil, startedAt: start)
        let half = TimerProgress.make(for: .running(active), now: start.addingTimeInterval(10 * 60))
        #expect(half.phase == .running)
        #expect(abs(half.fraction - 0.5) < 0.0001)
    }

    @Test
    func runningPomodoroClampsBeyondBell() {
        let active = ActiveSession(mode: .pomodoro(workMinutes: 20, breakMinutes: 5), intention: nil, startedAt: start)
        let over = TimerProgress.make(for: .running(active), now: start.addingTimeInterval(40 * 60))
        #expect(over.fraction == 1)
    }

    @Test
    func backwardClockClampsToZero() {
        let active = ActiveSession(mode: .pomodoro(workMinutes: 20, breakMinutes: 5), intention: nil, startedAt: start)
        let before = TimerProgress.make(for: .running(active), now: start.addingTimeInterval(-60))
        #expect(before.fraction == 0)
    }

    @Test
    func flowmodoroHasNoFractionalProgress() {
        let active = ActiveSession(mode: .flowmodoro, intention: nil, startedAt: start)
        let progress = TimerProgress.make(for: .running(active), now: start.addingTimeInterval(3600))
        #expect(progress.phase == .flowmodoro)
        #expect(progress.fraction == 0)
    }

    @Test
    func mainEndedAndOverflowAndFinishedAreFull() {
        let active = ActiveSession(mode: .pomodoro(workMinutes: 20, breakMinutes: 5), intention: nil, startedAt: start)
        #expect(TimerProgress.make(for: .mainEnded(active), now: start).phase == .mainEnded)
        #expect(TimerProgress.make(for: .mainEnded(active), now: start).fraction == 1)

        let overflow = TimerProgress.make(for: .overflow(active, until: start.addingTimeInterval(600)), now: start)
        #expect(overflow.phase == .overflow)
        #expect(overflow.fraction == 1)

        let session = Session(startedAt: start, endedAt: start.addingTimeInterval(1200), mode: .flowmodoro, endReason: .completed)
        let finished = TimerProgress.make(for: .finished(session), now: start)
        #expect(finished.phase == .finished)
        #expect(finished.fraction == 1)
    }

    @Test
    func initClampsOutOfRangeFraction() {
        #expect(TimerProgress(phase: .running, fraction: 2).fraction == 1)
        #expect(TimerProgress(phase: .running, fraction: -1).fraction == 0)
    }
}
