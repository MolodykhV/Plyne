import Foundation
import Testing
import PlyneCore
@testable import PlyneAnalytics

// Test fixtures build dates from known-good components; force-unwrapping the
// resulting Date is fine here.
// swiftlint:disable force_unwrapping

@Suite("PostMeetingEffectInsight")
struct PostMeetingEffectInsightTests {
    private var utc: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        cal.firstWeekday = 2
        return cal
    }

    private var reference: Date {
        DateComponents(calendar: utc, year: 2026, month: 5, day: 30, hour: 18, minute: 0).date!
    }

    private func at(daysAgo: Int, hour: Int, minute: Int = 0) -> Date {
        let dayStart = utc.date(byAdding: .day, value: -daysAgo, to: utc.startOfDay(for: reference))!
        return utc.date(byAdding: DateComponents(hour: hour, minute: minute), to: dayStart)!
    }

    private func sess(_ start: Date, minutes: Double) -> Session {
        Session(startedAt: start, endedAt: start.addingTimeInterval(minutes * 60), mode: .flowmodoro, endReason: .completed)
    }

    private func meeting(_ start: Date, minutes: Double) -> CalendarBlock {
        CalendarBlock(startedAt: start, endedAt: start.addingTimeInterval(minutes * 60), title: "Sync", kind: .meeting)
    }

    @Test
    func noMeetingsYieldsNoCard() {
        let sessions = (1...5).flatMap { day in
            [sess(at(daysAgo: day, hour: 9), minutes: 60), sess(at(daysAgo: day, hour: 14), minutes: 40)]
        }
        #expect(DashboardAnalytics.postMeetingEffect(sessions: sessions, meetings: [], endingAt: reference, calendar: utc) == nil)
    }

    @Test
    func shorterAfterMeetingsAcrossDaysReturnsInsight() {
        var sessions = [Session]()
        var meetings = [CalendarBlock]()
        for day in 1...5 {
            sessions.append(sess(at(daysAgo: day, hour: 8), minutes: 90))  // long, before the meeting
            meetings.append(meeting(at(daysAgo: day, hour: 10), minutes: 60))
            sessions.append(sess(at(daysAgo: day, hour: 11), minutes: 20))  // first after the meeting
            sessions.append(sess(at(daysAgo: day, hour: 14), minutes: 40))
        }
        let insight = DashboardAnalytics.postMeetingEffect(sessions: sessions, meetings: meetings, endingAt: reference, calendar: utc)
        #expect(insight?.dayCount == 5)
        #expect(insight?.isShorterAfterMeetings == true)
        // The 90-min pre-meeting session must land in the baseline, never as the
        // "after" session: after = 20, baseline = mean(90, 20, 40) = 50.
        #expect(insight.map { abs($0.afterMeetingMinutes - 20) < 0.0001 } == true)
        #expect(insight.map { abs($0.baselineMinutes - 50) < 0.0001 } == true)
        #expect(insight.map { abs($0.deltaFraction - (-0.6)) < 0.0001 } == true)
    }

    @Test
    func longerAfterMeetingsReportsPositiveDelta() {
        var sessions = [Session]()
        var meetings = [CalendarBlock]()
        for day in 1...5 {
            meetings.append(meeting(at(daysAgo: day, hour: 10), minutes: 60))
            sessions.append(sess(at(daysAgo: day, hour: 11), minutes: 90))
            sessions.append(sess(at(daysAgo: day, hour: 14), minutes: 10))
        }
        let insight = DashboardAnalytics.postMeetingEffect(sessions: sessions, meetings: meetings, endingAt: reference, calendar: utc)
        #expect(insight?.isShorterAfterMeetings == false)
        #expect(insight.map { $0.deltaFraction > 0.15 } == true)
    }

    @Test
    func gapWithinThresholdYieldsNoCard() {
        var sessions = [Session]()
        var meetings = [CalendarBlock]()
        for day in 1...5 {
            meetings.append(meeting(at(daysAgo: day, hour: 10), minutes: 60))
            sessions.append(sess(at(daysAgo: day, hour: 11), minutes: 38))  // after
            sessions.append(sess(at(daysAgo: day, hour: 14), minutes: 42))  // baseline mean = 40, gap -5%
        }
        #expect(DashboardAnalytics.postMeetingEffect(sessions: sessions, meetings: meetings, endingAt: reference, calendar: utc) == nil)
    }

    @Test
    func belowMinimumDaysYieldsNoCard() {
        var sessions = [Session]()
        var meetings = [CalendarBlock]()
        for day in 1...4 {  // strong signal, but only four days
            meetings.append(meeting(at(daysAgo: day, hour: 10), minutes: 60))
            sessions.append(sess(at(daysAgo: day, hour: 11), minutes: 20))
            sessions.append(sess(at(daysAgo: day, hour: 14), minutes: 60))
        }
        #expect(DashboardAnalytics.postMeetingEffect(sessions: sessions, meetings: meetings, endingAt: reference, calendar: utc) == nil)
    }

    @Test
    func minimumDeltaIsConfigurable() {
        var sessions = [Session]()
        var meetings = [CalendarBlock]()
        for day in 1...5 {
            sessions.append(sess(at(daysAgo: day, hour: 8), minutes: 90))
            meetings.append(meeting(at(daysAgo: day, hour: 10), minutes: 60))
            sessions.append(sess(at(daysAgo: day, hour: 11), minutes: 20))
            sessions.append(sess(at(daysAgo: day, hour: 14), minutes: 40))
        }
        // The same -0.6 signal disappears once the threshold is raised past it.
        #expect(
            DashboardAnalytics.postMeetingEffect(
                sessions: sessions, meetings: meetings, endingAt: reference, calendar: utc, minimumDelta: 0.7
            ) == nil
        )
    }

    @Test
    func nonMeetingBlocksAreIgnored() {
        var sessions = [Session]()
        var blocks = [CalendarBlock]()
        for day in 1...5 {
            // A lunch block is not a meeting — it must not anchor an "after" session.
            blocks.append(
                CalendarBlock(startedAt: at(daysAgo: day, hour: 10), endedAt: at(daysAgo: day, hour: 11), title: "Lunch", kind: .lunch)
            )
            sessions.append(sess(at(daysAgo: day, hour: 11), minutes: 20))
            sessions.append(sess(at(daysAgo: day, hour: 14), minutes: 60))
        }
        #expect(DashboardAnalytics.postMeetingEffect(sessions: sessions, meetings: blocks, endingAt: reference, calendar: utc) == nil)
    }

    @Test
    func overlappingMeetingsAnchorOnEarliestStartMeetingEnd() {
        // Each day has a long meeting A 09:00–11:00 and a nested short one
        // B 10:00–10:15. The anchor must be A's end (11:00 — the user is still
        // in A until then), not the soonest end (10:15). A session at 10:30 sits
        // inside A and must NOT be the "after" session; the first true post-
        // meeting session is at 11:30.
        var sessions = [Session]()
        var meetings = [CalendarBlock]()
        for day in 1...5 {
            meetings.append(meeting(at(daysAgo: day, hour: 9), minutes: 120))   // A
            meetings.append(meeting(at(daysAgo: day, hour: 10), minutes: 15))   // B (nested)
            sessions.append(sess(at(daysAgo: day, hour: 10, minute: 30), minutes: 60))  // during A
            sessions.append(sess(at(daysAgo: day, hour: 11, minute: 30), minutes: 20))  // first after A
            sessions.append(sess(at(daysAgo: day, hour: 14), minutes: 40))
        }
        let insight = DashboardAnalytics.postMeetingEffect(sessions: sessions, meetings: meetings, endingAt: reference, calendar: utc)
        // Anchored on 11:00, the after-session is the 20-min one (not the 60-min
        // session that is still inside meeting A). Had the anchor been min-end
        // (10:15), the after-session would be the 60-min one and the sign flip.
        #expect(insight.map { abs($0.afterMeetingMinutes - 20) < 0.0001 } == true)
        #expect(insight?.isShorterAfterMeetings == true)
    }
}

// swiftlint:enable force_unwrapping
