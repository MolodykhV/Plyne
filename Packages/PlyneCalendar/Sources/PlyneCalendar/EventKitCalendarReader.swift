import EventKit
import Foundation
import PlyneCore

/// EventKit-backed ``CalendarReading``.
///
/// An `actor` because `EKEventStore.events(matching:)` is synchronous and can
/// block while EventKit materializes recurrences — running it on the actor's
/// executor keeps it off the main thread. `EKEvent`/`EKEventStore` are not
/// `Sendable` and never leave the actor: each event is flattened to a
/// `Sendable` ``RawCalendarEvent`` before the result crosses back out.
public actor EventKitCalendarReader: CalendarReading {
    private let store = EKEventStore()

    public init() {}

    public func authorizationStatus() async -> CalendarAuthorization {
        Self.map(EKEventStore.authorizationStatus(for: .event))
    }

    public func requestAccess() async -> CalendarAuthorization {
        // Reading events requires full access on macOS 14+ (write-only cannot
        // read). The system sheet is the only prompt; we never pre-empt it.
        _ = try? await store.requestFullAccessToEvents()
        return Self.map(EKEventStore.authorizationStatus(for: .event))
    }

    public func todaysEvents(now: Date) async -> [RawCalendarEvent] {
        guard Self.map(EKEventStore.authorizationStatus(for: .event)) == .authorized else {
            return []
        }
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: now)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }

        let predicate = store.predicateForEvents(withStart: dayStart, end: dayEnd, calendars: nil)
        return store.events(matching: predicate).compactMap(Self.snapshot(of:))
    }

    // MARK: - EventKit → domain

    /// Flattens an `EKEvent` into a `Sendable` snapshot. Returns `nil` for
    /// events without a usable interval.
    private static func snapshot(of event: EKEvent) -> RawCalendarEvent? {
        guard let start = event.startDate, let end = event.endDate else { return nil }
        // More than one attendee means other people are involved (a meeting),
        // not a solo hold. `availability == .busy` is the conservative "busy"
        // signal; free/tentative time stays non-blocking.
        let hasOthers = (event.attendees?.count ?? 0) > 1
        // `eventIdentifier` is unreliable for detached recurrences / imported
        // events; fall back to intrinsic fields so distinct events still get
        // distinct (and refresh-stable) ids rather than all collapsing to "".
        let identifier = event.eventIdentifier ?? "\(event.calendarItemIdentifier)|\(start.timeIntervalSinceReferenceDate)|\(event.title ?? "")"
        return RawCalendarEvent(
            id: identifier,
            title: event.title ?? "",
            start: start,
            end: end,
            isAllDay: event.isAllDay,
            hasAttendees: hasOthers,
            isBusy: event.availability == .busy,
            isCancelled: event.status == .canceled
        )
    }

    private static func map(_ status: EKAuthorizationStatus) -> CalendarAuthorization {
        switch status {
        case .fullAccess:
            return .authorized
        case .denied, .writeOnly:
            // Write-only can't read events, so for our read-only feature it is
            // effectively "not connected"; the calm reconnect path applies.
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .notDetermined
        default:
            // The legacy `.authorized` case never occurs at our 26.0 minimum
            // (the OS reports `.fullAccess`); anything unknown is treated as
            // not-connected so the calm reconnect path applies.
            return .denied
        }
    }
}
