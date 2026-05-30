import Foundation

/// Finds the meeting (if any) happening at a given instant.
///
/// Only ``CalendarBlock/Kind/meeting`` blocks suppress the timer suggestion;
/// `.focus`/`.other` are informational and never block. Pure, so the rule is
/// testable without EventKit.
public enum MeetingNow {
    /// The meeting active at `now`, or `nil`.
    ///
    /// The interval is half-open `[start, end)`, so back-to-back meetings don't
    /// both match at the shared boundary. When several overlap, the
    /// latest-starting one wins (the most specific / most recently begun).
    public static func active(in blocks: [CalendarBlock], at now: Date) -> CalendarBlock? {
        blocks
            .filter { $0.kind == .meeting && $0.startedAt <= now && now < $0.endedAt }
            .max { $0.startedAt < $1.startedAt }
    }
}
