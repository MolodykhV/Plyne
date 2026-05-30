import Foundation

/// An EventKit-free snapshot of a calendar event.
///
/// `EKEvent` is not constructible in unit tests and lives only in the
/// macOS-only `PlyneCalendar` module. The adapter there flattens each event
/// into this `Sendable` value so the classification rules
/// (``CalendarBlockMapper``) stay pure and Linux-testable.
public struct RawCalendarEvent: Hashable, Sendable {
    /// The source event's stable identifier (e.g. `EKEvent.eventIdentifier`).
    /// Used to derive a stable ``CalendarBlock`` id so repeated fetches don't
    /// churn. May be empty if the source has none.
    public let id: String

    /// Display title.
    public let title: String

    /// Wall-clock start.
    public let start: Date

    /// Wall-clock end.
    public let end: Date

    /// Whether the event is an all-day banner.
    public let isAllDay: Bool

    /// Whether the event has other participants (a real meeting, not a solo
    /// hold).
    public let hasAttendees: Bool

    /// Whether the event marks the time as busy (vs free/tentative).
    public let isBusy: Bool

    /// Whether the event was cancelled.
    public let isCancelled: Bool

    /// Memberwise initializer.
    public init(
        id: String,
        title: String,
        start: Date,
        end: Date,
        isAllDay: Bool,
        hasAttendees: Bool,
        isBusy: Bool,
        isCancelled: Bool
    ) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.hasAttendees = hasAttendees
        self.isBusy = isBusy
        self.isCancelled = isCancelled
    }
}
