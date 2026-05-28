import Foundation

/// A non-overlapping interval pulled from the user's calendar.
///
/// `CalendarBlock` is the domain-side wrapper around an EventKit event,
/// so that `PlyneCore` stays Apple-framework-free. The mapping from
/// `EKEvent → CalendarBlock` lives in the macOS-only `PlyneCalendar`
/// module (Phase 2).
public struct CalendarBlock: Identifiable, Hashable, Sendable, Codable {
    /// Stable identifier. When the source event has its own stable id we
    /// reuse it; otherwise the calendar service assigns one.
    public let id: UUID

    /// Wall-clock start of the block.
    public let startedAt: Date

    /// Wall-clock end of the block.
    public let endedAt: Date

    /// Display title shown to the user.
    public let title: String

    /// Bucket the block falls into; drives how Plyne behaves during it
    /// (e.g. suppressing the timer suggestion during meetings).
    public let kind: Kind

    /// Bucket of a ``CalendarBlock``.
    public enum Kind: String, Hashable, Sendable, Codable, CaseIterable {
        /// A meeting, call, or any blocking event with other participants.
        case meeting

        /// User's lunch window (configurable in settings).
        case lunch

        /// A self-scheduled focus block, surfaced on the calendar but
        /// distinct from an actual Plyne session.
        case focus

        /// Anything not covered by the more specific kinds.
        case other
    }

    /// Memberwise initializer.
    public init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        title: String,
        kind: Kind
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.title = title
        self.kind = kind
    }

    /// Duration of the block.
    public var duration: TimeInterval { endedAt.timeIntervalSince(startedAt) }

    /// Throws if the block ends at or before it starts.
    public func validate() throws {
        guard endedAt > startedAt else {
            throw DomainError.calendarBlockEndedBeforeStarted
        }
    }
}
