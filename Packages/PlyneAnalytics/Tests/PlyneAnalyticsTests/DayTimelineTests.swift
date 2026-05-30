import Foundation
import Testing
import PlyneCore
@testable import PlyneAnalytics

// Test fixtures build dates from known-good components; force-unwrapping is fine.
// swiftlint:disable force_unwrapping

@Suite("DayTimeline")
struct DayTimelineTests {
    private var utc: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(hour: Int, minute: Int, day: Int = 27) -> Date {
        DateComponents(calendar: utc, year: 2026, month: 5, day: day, hour: hour, minute: minute).date!
    }

    private func session(hour: Int, minute: Int, minutes: Double, day: Int = 27) -> Session {
        let start = date(hour: hour, minute: minute, day: day)
        return Session(
            startedAt: start,
            endedAt: start.addingTimeInterval(minutes * 60),
            mode: .pomodoro(workMinutes: 25, breakMinutes: 5),
            intention: "code",
            endReason: .completed
        )
    }

    private func block(hour: Int, minute: Int, minutes: Double, day: Int = 27) -> CalendarBlock {
        let start = date(hour: hour, minute: minute, day: day)
        return CalendarBlock(startedAt: start, endedAt: start.addingTimeInterval(minutes * 60), title: "Standup", kind: .meeting)
    }

    @Test
    func emptyInputsYieldEmptyTimeline() {
        #expect(DashboardAnalytics.dayTimeline(sessions: [], calendarBlocks: [], on: date(hour: 12, minute: 0), calendar: utc).isEmpty)
    }

    @Test
    func mergesAndSortsByStart() {
        let items = DashboardAnalytics.dayTimeline(
            sessions: [session(hour: 14, minute: 0, minutes: 25), session(hour: 9, minute: 0, minutes: 50)],
            calendarBlocks: [block(hour: 11, minute: 0, minutes: 30)],
            on: date(hour: 12, minute: 0),
            calendar: utc
        )
        #expect(items.map(\.start) == [date(hour: 9, minute: 0), date(hour: 11, minute: 0), date(hour: 14, minute: 0)])
    }

    @Test
    func tieBreaksCalendarBlockBeforeSession() {
        let items = DashboardAnalytics.dayTimeline(
            sessions: [session(hour: 10, minute: 0, minutes: 25)],
            calendarBlocks: [block(hour: 10, minute: 0, minutes: 25)],
            on: date(hour: 12, minute: 0),
            calendar: utc
        )
        #expect(items.first?.isCalendarBlock == true)
        #expect(items.last?.isCalendarBlock == false)
    }

    @Test
    func excludesItemsOnOtherDays() {
        let items = DashboardAnalytics.dayTimeline(
            sessions: [session(hour: 10, minute: 0, minutes: 25, day: 26)],
            calendarBlocks: [block(hour: 10, minute: 0, minutes: 25, day: 28)],
            on: date(hour: 12, minute: 0, day: 27),
            calendar: utc
        )
        #expect(items.isEmpty)
    }

    @Test
    func includesItemThatStartedYesterdayAndRunsIntoTheDay() {
        // Started 23:30 the prior day, 60 min → crosses into day 27.
        let items = DashboardAnalytics.dayTimeline(
            sessions: [session(hour: 23, minute: 30, minutes: 60, day: 26)],
            calendarBlocks: [],
            on: date(hour: 12, minute: 0, day: 27),
            calendar: utc
        )
        #expect(items.count == 1)
        // Start is kept (not clipped to the day boundary).
        #expect(items.first?.start == date(hour: 23, minute: 30, day: 26))
    }

    @Test
    func runningSessionIsIncludedWithNilEnd() {
        let running = Session(startedAt: date(hour: 10, minute: 0), mode: .flowmodoro)
        let items = DashboardAnalytics.dayTimeline(sessions: [running], calendarBlocks: [], on: date(hour: 12, minute: 0), calendar: utc)
        #expect(items.count == 1)
        #expect(items.first?.isRunning == true)
        #expect(items.first?.end == nil)
    }

    @Test
    func orderingIsDeterministicRegardlessOfInputOrder() {
        // Same items, two input orders → identical output order.
        let early = session(hour: 9, minute: 0, minutes: 50)
        let late = session(hour: 14, minute: 0, minutes: 25)
        let mid = block(hour: 11, minute: 0, minutes: 30)
        let noon = date(hour: 12, minute: 0)
        let forward = DashboardAnalytics.dayTimeline(sessions: [early, late], calendarBlocks: [mid], on: noon, calendar: utc)
        let reversed = DashboardAnalytics.dayTimeline(sessions: [late, early], calendarBlocks: [mid], on: noon, calendar: utc)
        #expect(forward.map(\.id) == reversed.map(\.id))
        #expect(forward.map(\.id) == [early.id, mid.id, late.id])
    }
}

// swiftlint:enable force_unwrapping
