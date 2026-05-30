import Foundation
import PlyneCore

/// One entry in the day timeline — a focus session or a calendar block.
public struct DayTimelineItem: Identifiable, Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        case session(Session)
        case calendarBlock(CalendarBlock)
    }

    public let id: UUID
    public let start: Date
    /// `nil` only for a session still running.
    public let end: Date?
    public let kind: Kind

    public init(id: UUID, start: Date, end: Date?, kind: Kind) {
        self.id = id
        self.start = start
        self.end = end
        self.kind = kind
    }

    /// A session with no recorded end.
    public var isRunning: Bool { end == nil }

    var isCalendarBlock: Bool {
        if case .calendarBlock = kind { return true }
        return false
    }
}

public extension DashboardAnalytics {
    /// Merges sessions and calendar blocks that intersect `date`'s day into one
    /// time-ordered timeline. Items keep their true start/end (not clipped to
    /// the day) so the view can show "started yesterday" context. Sorted by
    /// start; on a tie a calendar block sorts before a session (context first),
    /// then by id for determinism. A running session is included with `end ==
    /// nil`.
    static func dayTimeline(
        sessions: [Session],
        calendarBlocks: [CalendarBlock],
        on date: Date,
        calendar: Calendar
    ) -> [DayTimelineItem] {
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }

        var items = [DayTimelineItem]()
        for session in sessions {
            let effectiveEnd = session.endedAt ?? .distantFuture
            guard session.startedAt < dayEnd, effectiveEnd > dayStart else { continue }
            items.append(DayTimelineItem(id: session.id, start: session.startedAt, end: session.endedAt, kind: .session(session)))
        }
        for block in calendarBlocks {
            guard block.startedAt < dayEnd, block.endedAt > dayStart else { continue }
            items.append(DayTimelineItem(id: block.id, start: block.startedAt, end: block.endedAt, kind: .calendarBlock(block)))
        }

        return items.sorted { lhs, rhs in
            if lhs.start != rhs.start { return lhs.start < rhs.start }
            if lhs.isCalendarBlock != rhs.isCalendarBlock { return lhs.isCalendarBlock }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }
}
