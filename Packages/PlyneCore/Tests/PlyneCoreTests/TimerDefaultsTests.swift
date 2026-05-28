import Foundation
import Testing
@testable import PlyneCore

@Suite("TimerDefaults")
struct TimerDefaultsTests {
    @Test
    func pomodoroDefaultsMatchConcept() {
        // Concept doc: "по умолчанию 25/5".
        #expect(Pomodoro.defaultWorkMinutes == 25)
        #expect(Pomodoro.defaultBreakMinutes == 5)
    }

    @Test
    func flowmodoroBreakUsesOneFifthRatioBelowCap() {
        // 25-minute work → 5-minute break (floor of 1500 / 5 = 300 s).
        #expect(Flowmodoro.recommendedBreak(after: 25 * 60) == 5 * 60)
        // 45-minute work → 9-minute break.
        #expect(Flowmodoro.recommendedBreak(after: 45 * 60) == 9 * 60)
    }

    @Test
    func flowmodoroBreakCapsAt30Minutes() {
        // Anything over 150 minutes of work should still cap at 1800 s.
        #expect(Flowmodoro.recommendedBreak(after: 3 * 60 * 60) == 30 * 60)
        #expect(Flowmodoro.recommendedBreak(after: 24 * 60 * 60) == 30 * 60)
    }

    @Test
    func flowmodoroBreakIsNonNegative() {
        #expect(Flowmodoro.recommendedBreak(after: 0) == 0)
        // Defensive: negative inputs are nonsensical but must not produce
        // negative breaks. The clamp inside `recommendedBreak` ensures this.
        #expect(Flowmodoro.recommendedBreak(after: -120) >= 0)
    }

    @Test
    func flowmodoroBreakUsesFloorRounding() {
        // 23 s of work → 23 / 5 = 4.6 → floors to 4 s.
        #expect(Flowmodoro.recommendedBreak(after: 23) == 4)
        // 9 s of work → 9 / 5 = 1.8 → floors to 1 s.
        #expect(Flowmodoro.recommendedBreak(after: 9) == 1)
    }

    @Test
    func overflowBoundsMatchConcept() {
        // Concept doc: "ещё 5–15 минут поверх таймера".
        #expect(Overflow.minMinutes == 5)
        #expect(Overflow.maxMinutes == 15)
        #expect((Overflow.minMinutes...Overflow.maxMinutes).contains(Overflow.defaultMinutes))
    }

    @Test
    func overflowClampingHoldsTheRange() {
        #expect(Overflow.clampedMinutes(1) == 5)
        #expect(Overflow.clampedMinutes(60) == 15)
        #expect(Overflow.clampedMinutes(10) == 10)
    }
}
