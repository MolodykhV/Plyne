import Foundation

/// Classifies a ``RawCalendarEvent`` into a ``CalendarBlock``, or drops it.
///
/// Pure and deterministic. The rules are intentionally conservative — only a
/// real meeting (busy time with other people) should suppress the timer
/// suggestion, so everything ambiguous stays non-blocking.
public enum CalendarBlockMapper {
    /// Maps one event, returning `nil` for events that should not surface as
    /// blocks (cancelled, zero-length/reversed, or all-day banners).
    ///
    /// Classification:
    /// - busy **and** has other attendees → ``CalendarBlock/Kind/meeting``
    /// - busy **and** solo → ``CalendarBlock/Kind/focus`` (a self-scheduled hold)
    /// - otherwise (free/tentative) → ``CalendarBlock/Kind/other``
    ///
    /// `.lunch` is never produced yet — it needs the configured lunch window,
    /// which is out of scope for this step.
    public static func block(from event: RawCalendarEvent) -> CalendarBlock? {
        guard !event.isCancelled, event.end > event.start, !event.isAllDay else {
            return nil
        }
        let kind: CalendarBlock.Kind
        switch (event.isBusy, event.hasAttendees) {
        case (true, true):
            kind = .meeting
        case (true, false):
            kind = .focus
        default:
            kind = .other
        }
        return CalendarBlock(
            id: DeterministicUUID.from(event.id),
            startedAt: event.start,
            endedAt: event.end,
            title: event.title,
            kind: kind
        )
    }

    /// Maps and filters a batch, preserving input order.
    public static func blocks(from events: [RawCalendarEvent]) -> [CalendarBlock] {
        events.compactMap(block(from:))
    }
}
