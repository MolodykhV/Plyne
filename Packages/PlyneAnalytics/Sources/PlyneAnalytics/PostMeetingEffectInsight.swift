import Foundation
import PlyneCore

/// How the first focus session after a meeting compares to a day's typical
/// session length, observed over a lookback window. Descriptive only — it
/// reports the gap, the surface decides whether the gap is worth surfacing and
/// always in the observer register (concept "Тональность аналитики").
public struct PostMeetingEffectInsight: Hashable, Sendable {
    /// Average minutes of the first session that followed a meeting, across the
    /// qualifying days.
    public let afterMeetingMinutes: Double
    /// Average minutes of all sessions on those same days — the day baseline.
    public let baselineMinutes: Double
    /// Signed fraction `(afterMeeting - baseline) / baseline`. Negative means
    /// the first post-meeting session tends to run shorter than the day's norm.
    public let deltaFraction: Double
    /// Distinct days that contributed a meeting→session pair.
    public let dayCount: Int

    public init(afterMeetingMinutes: Double, baselineMinutes: Double, deltaFraction: Double, dayCount: Int) {
        self.afterMeetingMinutes = afterMeetingMinutes
        self.baselineMinutes = baselineMinutes
        self.deltaFraction = deltaFraction
        self.dayCount = dayCount
    }

    /// `true` when post-meeting sessions tend to run shorter than the baseline.
    public var isShorterAfterMeetings: Bool { deltaFraction < 0 }
}

public extension DashboardAnalytics {
    /// Compares the first post-meeting focus session against the day's average
    /// session length, aggregated over the `lookbackDays` ending at `reference`.
    ///
    /// > Note (step 1.11): this algorithm is complete and unit-tested but is
    /// > **not yet wired into any surface**. Plyne does not persist calendar
    /// > history — `PlyneSchemaV1` deliberately omits a `CalendarEventCache`, so
    /// > only the current day's meetings exist at runtime, far short of the
    /// > multi-day sample this needs. It is kept ready for a later step that
    /// > lands calendar caching; until then it returns `nil` on live data.
    ///
    /// For each day it takes the earliest session starting at or after the day's
    /// first meeting end as the "post-meeting" session, and the mean of all that
    /// day's sessions as the baseline (the post-meeting session is included in
    /// the baseline — the literal "day average" — which mildly damps the gap).
    /// Returns `nil` unless at least `minimumDays` days contribute a pair and the
    /// absolute gap exceeds `minimumDelta`; a weak signal shows no card.
    ///
    /// - Parameters:
    ///   - sessions: candidate sessions; running and zero/negative spans are skipped.
    ///   - meetings: calendar blocks; only `.meeting` kind is considered.
    ///   - reference: the instant the lookback ends (typically "now").
    ///   - calendar: timezone/day-boundary source.
    ///   - lookbackDays: whole days back from the start of `reference`'s day.
    ///   - minimumDays: minimum days with a meeting→session pair.
    ///   - minimumDelta: minimum absolute fractional gap to surface.
    /// - Returns: the aggregated effect, or `nil` to show no card.
    static func postMeetingEffect(
        sessions: [Session],
        meetings: [CalendarBlock],
        endingAt reference: Date,
        calendar: Calendar,
        lookbackDays: Int = 14,
        minimumDays: Int = 5,
        minimumDelta: Double = 0.15
    ) -> PostMeetingEffectInsight? {
        guard lookbackDays >= 1, minimumDays >= 1 else { return nil }
        let referenceDayStart = calendar.startOfDay(for: reference)
        guard let lookbackStart = calendar.date(byAdding: .day, value: -lookbackDays, to: referenceDayStart) else {
            return nil
        }
        let lookback = DateInterval(start: lookbackStart, end: reference)

        let sessionsByDay = completedSessionsByDay(sessions, in: lookback, calendar: calendar)
        let meetingEndByDay = firstMeetingEndByDay(meetings, in: lookback, calendar: calendar)

        var pairs = [(after: Double, baseline: Double)]()
        for (day, daySessions) in sessionsByDay {
            guard let meetingEnd = meetingEndByDay[day],
                  let pair = postMeetingPair(daySessions: daySessions, meetingEnd: meetingEnd) else { continue }
            pairs.append(pair)
        }

        guard pairs.count >= minimumDays else { return nil }
        let afterMean = pairs.map(\.after).reduce(0, +) / Double(pairs.count)
        let baselineMean = pairs.map(\.baseline).reduce(0, +) / Double(pairs.count)
        guard baselineMean > 0 else { return nil }
        let delta = (afterMean - baselineMean) / baselineMean
        guard abs(delta) > minimumDelta else { return nil }

        return PostMeetingEffectInsight(
            afterMeetingMinutes: afterMean,
            baselineMinutes: baselineMean,
            deltaFraction: delta,
            dayCount: pairs.count
        )
    }
}

private extension DashboardAnalytics {
    /// Completed, positive-length sessions starting inside `lookback`, grouped
    /// by local day.
    static func completedSessionsByDay(
        _ sessions: [Session],
        in lookback: DateInterval,
        calendar: Calendar
    ) -> [Date: [Session]] {
        var result = [Date: [Session]]()
        for session in sessions {
            guard let end = session.endedAt, end > session.startedAt,
                  session.startedAt >= lookback.start, session.startedAt < lookback.end else { continue }
            result[calendar.startOfDay(for: session.startedAt), default: []].append(session)
        }
        return result
    }

    /// For each local day, the end time of that day's earliest-*starting*
    /// meeting (ties broken toward the later end, i.e. the meeting that keeps
    /// the user busy longest). Non-`.meeting` blocks are ignored. This anchors
    /// the "after a meeting" session on when the first meeting clears, not on
    /// the soonest any meeting happens to end — the two differ when a day's
    /// meetings overlap or nest.
    static func firstMeetingEndByDay(
        _ meetings: [CalendarBlock],
        in lookback: DateInterval,
        calendar: Calendar
    ) -> [Date: Date] {
        var earliest = [Date: (start: Date, end: Date)]()
        for meeting in meetings where meeting.kind == .meeting {
            guard meeting.endedAt > meeting.startedAt,
                  meeting.startedAt >= lookback.start, meeting.startedAt < lookback.end else { continue }
            let day = calendar.startOfDay(for: meeting.startedAt)
            guard let current = earliest[day] else {
                earliest[day] = (meeting.startedAt, meeting.endedAt)
                continue
            }
            let startsEarlier = meeting.startedAt < current.start
            let sameStartRunsLonger = meeting.startedAt == current.start && meeting.endedAt > current.end
            if startsEarlier || sameStartRunsLonger {
                earliest[day] = (meeting.startedAt, meeting.endedAt)
            }
        }
        return earliest.mapValues(\.end)
    }

    /// The first session at or after `meetingEnd` and the day's mean session
    /// length, both in minutes, or `nil` if the day has no post-meeting session.
    static func postMeetingPair(daySessions: [Session], meetingEnd: Date) -> (after: Double, baseline: Double)? {
        let durations = daySessions.compactMap(\.duration)
        guard !durations.isEmpty else { return nil }
        let firstAfter = daySessions
            .filter { $0.startedAt >= meetingEnd }
            .min { $0.startedAt < $1.startedAt }
        guard let afterDuration = firstAfter?.duration else { return nil }
        let baseline = durations.reduce(0, +) / Double(durations.count)
        return (afterDuration / 60, baseline / 60)
    }
}
