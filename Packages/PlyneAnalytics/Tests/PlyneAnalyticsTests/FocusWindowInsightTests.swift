import Foundation
import Testing
import PlyneCore
@testable import PlyneAnalytics

// Test fixtures build dates from known-good components; force-unwrapping the
// resulting Date is fine here.
// swiftlint:disable force_unwrapping

@Suite("FocusWindowInsight")
struct FocusWindowInsightTests {
    /// A Monday-first UTC calendar for stable, timezone-free assertions.
    private var utc: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        cal.firstWeekday = 2
        return cal
    }

    /// `daysAgo` days before the reference at `hour:minute`, for `minutes` long.
    private func session(daysAgo: Int, hour: Int, minute: Int = 0, minutes: Double, reference: Date) -> Session {
        let dayStart = utc.date(byAdding: .day, value: -daysAgo, to: utc.startOfDay(for: reference))!
        let start = utc.date(byAdding: DateComponents(hour: hour, minute: minute), to: dayStart)!
        return Session(startedAt: start, endedAt: start.addingTimeInterval(minutes * 60), mode: .flowmodoro, endReason: .completed)
    }

    private var reference: Date {
        DateComponents(calendar: utc, year: 2026, month: 5, day: 30, hour: 18, minute: 0).date!
    }

    @Test
    func noSessionsYieldsNoCard() {
        #expect(DashboardAnalytics.bestFocusWindow(sessions: [], endingAt: reference, calendar: utc) == nil)
    }

    @Test
    func belowMinimumSamplesYieldsNoCard() {
        // Four sessions clustered at 09:00 — a clear band, but under the gate.
        let sessions = (1...4).map { session(daysAgo: $0, hour: 9, minutes: 60, reference: reference) }
        #expect(DashboardAnalytics.bestFocusWindow(sessions: sessions, endingAt: reference, calendar: utc) == nil)
    }

    @Test
    func morningClusterReturnsItsBand() {
        // Six days, each a 09:00–10:00 session: the band should lead on hour 9.
        let sessions = (1...6).map { session(daysAgo: $0, hour: 9, minutes: 60, reference: reference) }
        let insight = DashboardAnalytics.bestFocusWindow(sessions: sessions, endingAt: reference, calendar: utc)
        #expect(insight?.startHour == 9)
        #expect(insight?.endHour == 11)
        #expect(insight?.sessionCount == 6)
        #expect(insight.map { abs($0.minutes - 360) < 0.0001 } == true)
    }

    @Test
    func twoHourClusterIsFavouredOverASingleBusyHour() {
        // Five days of 14:00–16:00 work (two full hours) must beat five short
        // 09:00 sessions: the 14–16 band sums higher.
        var sessions = (1...5).map { session(daysAgo: $0, hour: 14, minutes: 120, reference: reference) }
        sessions += (1...5).map { session(daysAgo: $0, hour: 9, minutes: 20, reference: reference) }
        let insight = DashboardAnalytics.bestFocusWindow(sessions: sessions, endingAt: reference, calendar: utc)
        #expect(insight?.startHour == 14)
        #expect(insight?.endHour == 16)
    }

    @Test
    func busiestButSingleDayBandIsRejected() {
        // Enough sessions overall, but the busiest band sits on one day only:
        // not a recurring pattern, so no card (honours "usually").
        var sessions = [session(daysAgo: 1, hour: 9, minutes: 240, reference: reference)] // one huge morning
        sessions += (2...6).map { session(daysAgo: $0, hour: 15, minutes: 10, reference: reference) } // scattered afternoons
        let insight = DashboardAnalytics.bestFocusWindow(sessions: sessions, endingAt: reference, calendar: utc)
        #expect(insight == nil)
    }

    @Test
    func sessionsOlderThanLookbackAreExcluded() {
        // Five sessions all 20 days back — outside a 14-day lookback.
        let sessions = (20...24).map { session(daysAgo: $0, hour: 9, minutes: 60, reference: reference) }
        #expect(DashboardAnalytics.bestFocusWindow(sessions: sessions, endingAt: reference, calendar: utc) == nil)
    }

    @Test
    func runningSessionsAreSkipped() {
        let dayStart = utc.date(byAdding: .day, value: -1, to: utc.startOfDay(for: reference))!
        let start = utc.date(byAdding: .hour, value: 9, to: dayStart)!
        let running = Session(startedAt: start, mode: .flowmodoro)
        var sessions = [running]
        sessions += (2...4).map { session(daysAgo: $0, hour: 9, minutes: 60, reference: reference) }
        // Only three completed sessions remain — below the gate.
        #expect(DashboardAnalytics.bestFocusWindow(sessions: sessions, endingAt: reference, calendar: utc) == nil)
    }

    @Test
    func sampleGateIsConfigurable() {
        // Five sessions on five distinct days return a card; raising the gate
        // above the sample removes it.
        let sessions = (1...5).map { session(daysAgo: $0, hour: 10, minutes: 60, reference: reference) }
        #expect(DashboardAnalytics.bestFocusWindow(sessions: sessions, endingAt: reference, calendar: utc) != nil)
        #expect(
            DashboardAnalytics.bestFocusWindow(
                sessions: sessions, endingAt: reference, calendar: utc, minimumSessions: 6
            ) == nil
        )
    }

    @Test
    func lookbackLowerBoundIncludesDay14AndExcludesDay15() {
        // The 14-day lookback is half-open from the start of the day 14 days
        // back. A session exactly on that lower bound must count; one a day
        // earlier must not. Four deep-inside sessions plus the boundary one make
        // the gate (5) — so the card's presence pins which side of the edge the
        // fifth session lands on.
        let inside = (1...4).map { session(daysAgo: $0, hour: 10, minutes: 60, reference: reference) }
        let atBound = session(daysAgo: 14, hour: 10, minutes: 60, reference: reference)
        let beyond = session(daysAgo: 15, hour: 10, minutes: 60, reference: reference)
        #expect(DashboardAnalytics.bestFocusWindow(sessions: inside + [atBound], endingAt: reference, calendar: utc) != nil)
        #expect(DashboardAnalytics.bestFocusWindow(sessions: inside + [beyond], endingAt: reference, calendar: utc) == nil)
    }

    @Test
    func dstSpringForwardIsWalkedSafely() {
        // Berlin spring-forward 2026-03-29: 02:00 jumps to 03:00. A single
        // 01:30 → 03:30 session is one real hour; the hour-walk must terminate
        // and bucket real elapsed minutes (30 in hour 1, 30 in hour 3), so the
        // 2-hour band leading on hour 1 reports 30, never a doubled 120.
        var berlin = Calendar(identifier: .gregorian)
        berlin.timeZone = TimeZone(identifier: "Europe/Berlin")!
        berlin.firstWeekday = 2
        let ref = DateComponents(calendar: berlin, year: 2026, month: 3, day: 30, hour: 12).date!
        let start = DateComponents(calendar: berlin, year: 2026, month: 3, day: 29, hour: 1, minute: 30).date!
        let end = DateComponents(calendar: berlin, year: 2026, month: 3, day: 29, hour: 3, minute: 30).date!
        let dst = Session(startedAt: start, endedAt: end, mode: .flowmodoro, endReason: .completed)
        let insight = DashboardAnalytics.bestFocusWindow(
            sessions: [dst], endingAt: ref, calendar: berlin, minimumSessions: 1, minimumActiveDays: 1
        )
        #expect(insight?.startHour == 1)
        #expect(insight.map { abs($0.minutes - 30) < 0.0001 } == true)
    }
}

// swiftlint:enable force_unwrapping
