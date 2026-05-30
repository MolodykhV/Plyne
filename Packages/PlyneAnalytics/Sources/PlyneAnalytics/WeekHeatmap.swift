import Foundation
import PlyneCore

/// Focus minutes that landed in one weekday × hour cell.
public struct HeatmapCell: Hashable, Sendable {
    /// 0…6 from the week's first day (honours the calendar's `firstWeekday`).
    public let dayIndex: Int
    /// 0…23, the wall-clock hour.
    public let hour: Int
    /// Focus minutes accumulated in this cell.
    public let minutes: Double

    public init(dayIndex: Int, hour: Int, minutes: Double) {
        self.dayIndex = dayIndex
        self.hour = hour
        self.minutes = minutes
    }
}

/// A dense 7×24 grid of focus minutes for one week. The model carries no
/// colour and no "score" — the view maps ``normalizedIntensity(day:hour:)`` to
/// one accent's opacity. Self-relative by design (intensity is against this
/// week's own busiest cell), so it never reads as an absolute rating.
public struct WeekHeatmap: Sendable {
    /// Start of the week's first day (a start-of-day instant).
    public let weekStart: Date
    /// 168 cells, row-major: `index = dayIndex * 24 + hour`.
    public let cells: [HeatmapCell]
    /// The busiest cell's minutes; 0 when the week is empty.
    public let maxMinutes: Double

    public init(weekStart: Date, cells: [HeatmapCell], maxMinutes: Double) {
        self.weekStart = weekStart
        self.cells = cells
        self.maxMinutes = maxMinutes
    }

    /// Minutes in a cell. `day` 0…6, `hour` 0…23.
    public func minutes(day: Int, hour: Int) -> Double {
        guard day >= 0, day < 7, hour >= 0, hour < 24 else { return 0 }
        return cells[day * 24 + hour].minutes
    }

    /// Cell minutes relative to the week's busiest cell, in `0...1` (0 when the
    /// week is empty — no divide-by-zero).
    public func normalizedIntensity(day: Int, hour: Int) -> Double {
        guard maxMinutes > 0 else { return 0 }
        return min(1, minutes(day: day, hour: hour) / maxMinutes)
    }
}

public extension DashboardAnalytics {
    /// Aggregates sessions into a ``WeekHeatmap`` for the week containing
    /// `date`. A session's focus time is split across the hour cells it covers
    /// and clipped to the week. Running sessions (no `endedAt`) and
    /// zero/negative spans are skipped. `calendar` is injected for timezone and
    /// week-start correctness (and DST is handled by walking hour boundaries
    /// rather than assuming 3600-second hours).
    static func weekHeatmap(
        sessions: [Session],
        weekContaining date: Date,
        calendar: Calendar
    ) -> WeekHeatmap {
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start
            ?? calendar.startOfDay(for: date)
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart

        var grid = [Double](repeating: 0, count: 7 * 24)
        for session in sessions {
            guard let end = session.endedAt else { continue }
            let clippedStart = max(session.startedAt, weekStart)
            let clippedEnd = min(end, weekEnd)
            guard clippedEnd > clippedStart else { continue }

            var cursor = clippedStart
            while cursor < clippedEnd {
                guard let hourStart = calendar.dateInterval(of: .hour, for: cursor)?.start,
                      let nextHour = calendar.date(byAdding: .hour, value: 1, to: hourStart) else { break }
                let segmentEnd = min(clippedEnd, nextHour)
                let minutes = segmentEnd.timeIntervalSince(cursor) / 60
                let hour = calendar.component(.hour, from: cursor)
                let dayIndex = calendar.dateComponents(
                    [.day],
                    from: weekStart,
                    to: calendar.startOfDay(for: cursor)
                ).day ?? -1
                if dayIndex >= 0, dayIndex < 7, hour >= 0, hour < 24 {
                    grid[dayIndex * 24 + hour] += minutes
                }
                cursor = segmentEnd
            }
        }

        var cells = [HeatmapCell]()
        cells.reserveCapacity(7 * 24)
        for day in 0..<7 {
            for hour in 0..<24 {
                cells.append(HeatmapCell(dayIndex: day, hour: hour, minutes: grid[day * 24 + hour]))
            }
        }
        return WeekHeatmap(weekStart: weekStart, cells: cells, maxMinutes: grid.max() ?? 0)
    }
}
