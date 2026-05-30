import Foundation
import Testing
import PlyneCore
@testable import PlyneAnalytics

// Test fixtures build dates from known-good components; force-unwrapping the
// resulting Date is fine here.
// swiftlint:disable force_unwrapping function_parameter_count

@Suite("WeekHeatmap")
struct WeekHeatmapTests {
    /// A Monday-first UTC calendar for stable, timezone-free assertions.
    private var utc: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        cal.firstWeekday = 2 // Monday
        return cal
    }

    /// Berlin, which observes DST, for the spring-forward case.
    private var berlin: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Berlin")!
        cal.firstWeekday = 2
        return cal
    }

    private func date(_ calendar: Calendar, year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        DateComponents(calendar: calendar, year: year, month: month, day: day, hour: hour, minute: minute).date!
    }

    private func session(start: Date, minutes: Double) -> Session {
        Session(startedAt: start, endedAt: start.addingTimeInterval(minutes * 60), mode: .flowmodoro, endReason: .completed)
    }

    // Wednesday 2026-05-27 is dayIndex 2 in a Monday-first week.
    private func wed(_ calendar: Calendar, hour: Int, minute: Int) -> Date {
        date(calendar, year: 2026, month: 5, day: 27, hour: hour, minute: minute)
    }

    @Test
    func emptyWeekHasZeroCellsAndNoMax() {
        let heatmap = DashboardAnalytics.weekHeatmap(sessions: [], weekContaining: wed(utc, hour: 12, minute: 0), calendar: utc)
        #expect(heatmap.cells.count == 168)
        #expect(heatmap.maxMinutes == 0)
        #expect(heatmap.normalizedIntensity(day: 0, hour: 9) == 0)
        #expect(heatmap.cells.allSatisfy { $0.minutes == 0 })
    }

    @Test
    func singleSessionLandsInItsHourAndDay() {
        let heatmap = DashboardAnalytics.weekHeatmap(
            sessions: [session(start: wed(utc, hour: 14, minute: 10), minutes: 30)],
            weekContaining: wed(utc, hour: 0, minute: 0),
            calendar: utc
        )
        #expect(heatmap.minutes(day: 2, hour: 14) == 30)
        #expect(heatmap.maxMinutes == 30)
        #expect(heatmap.normalizedIntensity(day: 2, hour: 14) == 1)
    }

    @Test
    func sessionSplitsAcrossHourBoundary() {
        // 14:50 → 15:20 = 10 min in hour 14, 20 min in hour 15.
        let heatmap = DashboardAnalytics.weekHeatmap(
            sessions: [session(start: wed(utc, hour: 14, minute: 50), minutes: 30)],
            weekContaining: wed(utc, hour: 0, minute: 0),
            calendar: utc
        )
        #expect(heatmap.minutes(day: 2, hour: 14) == 10)
        #expect(heatmap.minutes(day: 2, hour: 15) == 20)
    }

    @Test
    func exactHourBoundaryIsHalfOpen() {
        // 14:00 → 15:00 → 60 min in hour 14, 0 in hour 15.
        let heatmap = DashboardAnalytics.weekHeatmap(
            sessions: [session(start: wed(utc, hour: 14, minute: 0), minutes: 60)],
            weekContaining: wed(utc, hour: 0, minute: 0),
            calendar: utc
        )
        #expect(heatmap.minutes(day: 2, hour: 14) == 60)
        #expect(heatmap.minutes(day: 2, hour: 15) == 0)
    }

    @Test
    func overnightSessionSplitsAcrossDays() {
        // Wed 23:30 → Thu 00:30 = 30 min (Wed, 23) + 30 min (Thu, 0).
        let heatmap = DashboardAnalytics.weekHeatmap(
            sessions: [session(start: wed(utc, hour: 23, minute: 30), minutes: 60)],
            weekContaining: wed(utc, hour: 0, minute: 0),
            calendar: utc
        )
        #expect(heatmap.minutes(day: 2, hour: 23) == 30)
        #expect(heatmap.minutes(day: 3, hour: 0) == 30)
    }

    @Test
    func sessionOutsideWeekContributesNothing() {
        let earlier = date(utc, year: 2026, month: 5, day: 18, hour: 10, minute: 0)
        let heatmap = DashboardAnalytics.weekHeatmap(
            sessions: [session(start: earlier, minutes: 60)],
            weekContaining: wed(utc, hour: 0, minute: 0),
            calendar: utc
        )
        #expect(heatmap.maxMinutes == 0)
    }

    @Test
    func runningSessionIsSkipped() {
        let running = Session(startedAt: wed(utc, hour: 10, minute: 0), mode: .flowmodoro)
        let heatmap = DashboardAnalytics.weekHeatmap(sessions: [running], weekContaining: wed(utc, hour: 0, minute: 0), calendar: utc)
        #expect(heatmap.maxMinutes == 0)
    }

    @Test
    func zeroAndReversedSessionsAreSkipped() {
        let start = wed(utc, hour: 10, minute: 0)
        let zero = Session(startedAt: start, endedAt: start, mode: .flowmodoro, endReason: .userEnded)
        let reversed = Session(startedAt: start, endedAt: start.addingTimeInterval(-600), mode: .flowmodoro, endReason: .userEnded)
        let heatmap = DashboardAnalytics.weekHeatmap(sessions: [zero, reversed], weekContaining: start, calendar: utc)
        #expect(heatmap.maxMinutes == 0)
    }

    @Test
    func dstSpringForwardKeepsRealElapsedMinutes() {
        // Berlin spring-forward 2026-03-29: 02:00 jumps to 03:00. A session
        // 01:30 → 03:30 wall-clock is 1 real hour (60 min), not 120.
        let start = date(berlin, year: 2026, month: 3, day: 29, hour: 1, minute: 30)
        let end = date(berlin, year: 2026, month: 3, day: 29, hour: 3, minute: 30)
        let dst = Session(startedAt: start, endedAt: end, mode: .flowmodoro, endReason: .completed)
        let heatmap = DashboardAnalytics.weekHeatmap(sessions: [dst], weekContaining: start, calendar: berlin)
        let total = heatmap.cells.reduce(0) { $0 + $1.minutes }
        #expect(abs(total - 60) < 0.0001)
    }

    @Test
    func dstFallBackAccumulatesTheRepeatedHour() {
        // Berlin fall-back 2026-10-25: 02:00 occurs twice. A session 01:30 →
        // 04:00 wall-clock is 210 real minutes; the repeated wall-clock hour 2
        // must receive both passes (120 min) and the loop must still terminate.
        let start = date(berlin, year: 2026, month: 10, day: 25, hour: 1, minute: 30)
        let end = date(berlin, year: 2026, month: 10, day: 25, hour: 4, minute: 0)
        let session = Session(startedAt: start, endedAt: end, mode: .flowmodoro, endReason: .completed)
        let heatmap = DashboardAnalytics.weekHeatmap(sessions: [session], weekContaining: start, calendar: berlin)
        let dayIndex = berlin.dateComponents([.day], from: heatmap.weekStart, to: berlin.startOfDay(for: start)).day ?? -1
        let total = heatmap.cells.reduce(0) { $0 + $1.minutes }
        #expect(abs(total - 210) < 0.0001)
        #expect(abs(heatmap.minutes(day: dayIndex, hour: 2) - 120) < 0.0001)
    }
}

// swiftlint:enable force_unwrapping function_parameter_count
