import Foundation
import PlyneCore

/// Plyne's view of calendar authorization, decoupled from EventKit's enum.
public enum CalendarAuthorization: Sendable, Equatable {
    /// Never asked — the explicit opt-in is offered.
    case notDetermined
    /// Granted full (read) access.
    case authorized
    /// User declined; can be re-enabled in System Settings.
    case denied
    /// Blocked by policy (MDM/parental); the user cannot change it.
    case restricted
}

/// The calendar source the app depends on. An abstraction so the EventKit
/// implementation can be swapped for a fake in tests, and so the UI never
/// imports EventKit. All results are `Sendable` value types.
public protocol CalendarReading: Sendable {
    /// The current authorization, read without prompting.
    func authorizationStatus() async -> CalendarAuthorization

    /// Requests read access. Called only from the explicit opt-in — never at
    /// launch. Returns the resulting authorization.
    func requestAccess() async -> CalendarAuthorization

    /// Today's events as EventKit-free snapshots, relative to `now`. Returns
    /// empty when not authorized.
    func todaysEvents(now: Date) async -> [RawCalendarEvent]
}
