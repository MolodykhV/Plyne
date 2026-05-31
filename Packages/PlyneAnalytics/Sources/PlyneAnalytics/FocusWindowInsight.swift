import Foundation
import PlyneCore

/// The recurring time-of-day band where a user's focus minutes concentrate over
/// a lookback window. Descriptive only: it names *when* focus tends to land,
/// never whether that is good, bad, or what the user "should" do. The concept
/// doc ("Тональность аналитики") makes this the product thesis — an observation,
/// not a verdict.
public struct FocusWindowInsight: Hashable, Sendable {
    /// First hour of the band (0…23, wall-clock in the supplied calendar).
    public let startHour: Int
    /// Hour the band ends, exclusive — `startHour + windowHours`. May be 24
    /// (midnight of the next day) for a band that ends at the day boundary.
    public let endHour: Int
    /// Focus minutes that landed in this band across the whole lookback.
    public let minutes: Double
    /// Completed sessions counted in the lookback — the sample behind the card.
    public let sessionCount: Int

    public init(startHour: Int, endHour: Int, minutes: Double, sessionCount: Int) {
        self.startHour = startHour
        self.endHour = endHour
        self.minutes = minutes
        self.sessionCount = sessionCount
    }
}

public extension DashboardAnalytics {
    /// The contiguous `windowHours`-long wall-clock band carrying the most focus
    /// minutes over the `lookbackDays` ending at `reference`.
    ///
    /// Returns `nil` — meaning *show no card* — unless the sample is large
    /// enough to be honest about: at least `minimumSessions` completed sessions
    /// in the lookback, a busiest band that actually carries focus, and that
    /// band recurring on at least `minimumActiveDays` distinct days (so the copy
    /// can say focus "usually" lands there rather than pointing at one outlier).
    /// Per the concept's hard rule a weak or small sample yields no card, never
    /// a "you did nothing" message.
    ///
    /// Focus time is split across the hour boundaries it covers and accumulated
    /// into hour-of-day buckets; walking real hour boundaries (rather than
    /// assuming 3600-second hours) keeps it correct across DST. `calendar` is
    /// injected for timezone and hour correctness.
    ///
    /// - Parameters:
    ///   - sessions: candidate sessions; running and zero/negative spans are skipped.
    ///   - reference: the instant the lookback ends (typically "now").
    ///   - calendar: timezone/hour source.
    ///   - lookbackDays: whole days back from the start of `reference`'s day.
    ///   - windowHours: band length, 1…24.
    ///   - minimumSessions: sample-size gate over the whole lookback.
    ///   - minimumActiveDays: distinct days the busiest band must recur on.
    /// - Returns: the busiest qualifying band, or `nil` to show no card.
    static func bestFocusWindow(
        sessions: [Session],
        endingAt reference: Date,
        calendar: Calendar,
        lookbackDays: Int = 14,
        windowHours: Int = 2,
        minimumSessions: Int = 5,
        minimumActiveDays: Int = 2
    ) -> FocusWindowInsight? {
        guard windowHours >= 1, windowHours <= 24, lookbackDays >= 1 else { return nil }
        let referenceDayStart = calendar.startOfDay(for: reference)
        guard let lookbackStart = calendar.date(byAdding: .day, value: -lookbackDays, to: referenceDayStart) else {
            return nil
        }

        let focus = hourlyFocus(
            sessions: sessions,
            lookback: DateInterval(start: lookbackStart, end: reference),
            calendar: calendar
        )
        guard focus.sessionCount >= minimumSessions,
              let band = busiestBand(minutesByHour: focus.minutesByHour, windowHours: windowHours) else {
            return nil
        }

        var activeDays = Set<Date>()
        for hour in band.start..<(band.start + windowHours) { activeDays.formUnion(focus.daysByHour[hour]) }
        guard activeDays.count >= minimumActiveDays else { return nil }

        return FocusWindowInsight(
            startHour: band.start,
            endHour: band.start + windowHours,
            minutes: band.minutes,
            sessionCount: focus.sessionCount
        )
    }
}

/// Per-hour-of-day focus totals over a lookback, with the distinct days each
/// hour saw focus and the number of contributing sessions.
private struct HourlyFocus {
    let minutesByHour: [Double]
    let daysByHour: [Set<Date>]
    let sessionCount: Int
}

private extension DashboardAnalytics {
    /// Splits each completed session's minutes across the wall-clock hours it
    /// covers into hour-of-day buckets (DST-safe by walking real hour
    /// boundaries). Membership is by `startedAt` — a session belongs to the
    /// lookback iff it *starts* inside it (matching `SessionRepository`'s
    /// `startedAt`-based query and the sibling `completedSessionsByDay`), so a
    /// session straddling the lower bound is not credited to the sample. A
    /// session running past `lookback.end` is clipped to it.
    static func hourlyFocus(sessions: [Session], lookback: DateInterval, calendar: Calendar) -> HourlyFocus {
        var minutesByHour = [Double](repeating: 0, count: 24)
        var daysByHour = [Set<Date>](repeating: [], count: 24)
        var sessionCount = 0

        for session in sessions {
            guard let end = session.endedAt, end > session.startedAt,
                  session.startedAt >= lookback.start, session.startedAt < lookback.end else { continue }
            sessionCount += 1

            let clippedEnd = min(end, lookback.end)
            var cursor = session.startedAt
            while cursor < clippedEnd {
                guard let hourStart = calendar.dateInterval(of: .hour, for: cursor)?.start,
                      let nextHour = calendar.date(byAdding: .hour, value: 1, to: hourStart) else { break }
                let segmentEnd = min(clippedEnd, nextHour)
                let hour = calendar.component(.hour, from: cursor)
                if hour >= 0, hour < 24 {
                    minutesByHour[hour] += segmentEnd.timeIntervalSince(cursor) / 60
                    daysByHour[hour].insert(calendar.startOfDay(for: cursor))
                }
                cursor = segmentEnd
            }
        }
        return HourlyFocus(minutesByHour: minutesByHour, daysByHour: daysByHour, sessionCount: sessionCount)
    }

    /// The contiguous `windowHours` band with the most minutes. Ties go to the
    /// band whose first hour carries more focus (so a single-hour cluster leads
    /// the band rather than being reported an hour early), then to the earliest
    /// start. Returns `nil` when no band carries focus.
    static func busiestBand(minutesByHour: [Double], windowHours: Int) -> (start: Int, minutes: Double)? {
        var bestStart = -1
        var bestMinutes = 0.0
        var bestLeadMinutes = -1.0
        for start in 0...(24 - windowHours) {
            var sum = 0.0
            for hour in start..<(start + windowHours) { sum += minutesByHour[hour] }
            let leadMinutes = minutesByHour[start]
            if sum > bestMinutes || (sum == bestMinutes && bestStart >= 0 && leadMinutes > bestLeadMinutes) {
                bestMinutes = sum
                bestStart = start
                bestLeadMinutes = leadMinutes
            }
        }
        guard bestStart >= 0, bestMinutes > 0 else { return nil }
        return (bestStart, bestMinutes)
    }
}
