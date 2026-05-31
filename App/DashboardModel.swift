import Foundation
import Observation
import PlyneAnalytics
import PlyneCore

/// Read-model for the dashboard window: this week's heatmap and the selected
/// day's timeline. Kept separate from `PlyneStore` (which owns the live timer)
/// — it shares the same repository and reads today's calendar blocks through a
/// closure, but holds its own navigable day and loads on demand.
@MainActor
@Observable
final class DashboardModel {
    /// This week's focus heatmap, or `nil` until first load.
    private(set) var weekHeatmap: WeekHeatmap?

    /// Time-ordered items for ``day``.
    private(set) var timeline: [DayTimelineItem] = []

    /// The recurring focus band over the last two weeks, or `nil` when the
    /// sample is too small or the signal too weak to surface a card.
    private(set) var focusWindow: FocusWindowInsight?

    /// The day the timeline shows (start-of-day). Navigable, never future.
    private(set) var day: Date

    /// Lookback span for the insight cards. Two weeks balances enough sample
    /// against staying recent (concept §1.11).
    private let insightLookbackDays = 14

    private let repository: any SessionRepository
    private let now: @Sendable () -> Date
    private let calendar: Calendar
    private let todaysBlocks: @MainActor () -> [CalendarBlock]

    init(
        repository: any SessionRepository,
        todaysBlocks: @escaping @MainActor () -> [CalendarBlock],
        calendar: Calendar = .current,
        now: @Sendable @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.todaysBlocks = todaysBlocks
        self.calendar = calendar
        self.now = now
        self.day = calendar.startOfDay(for: now())
    }

    /// `true` while the timeline is showing a day before today (so "next" is
    /// offered only into the past — Plyne records no future sessions).
    var canStepForward: Bool {
        day < calendar.startOfDay(for: now())
    }

    /// Loads the week heatmap, the insight cards, and the current day's timeline.
    func load() {
        Task {
            await reloadWeek()
            await reloadInsights()
            await reloadTimeline()
        }
    }

    /// Moves the timeline by whole days (clamped so it never shows the future).
    func stepDay(by days: Int) {
        guard let moved = calendar.date(byAdding: .day, value: days, to: day) else { return }
        let candidate = calendar.startOfDay(for: moved)
        guard candidate <= calendar.startOfDay(for: now()) else { return }
        day = candidate
        Task { await reloadTimeline() }
    }

    private func reloadWeek() async {
        let reference = now()
        let week = calendar.dateInterval(of: .weekOfYear, for: reference)
            ?? DateInterval(start: calendar.startOfDay(for: reference), duration: 7 * 86_400)
        let sessions = (try? await repository.sessions(in: week)) ?? []
        weekHeatmap = DashboardAnalytics.weekHeatmap(sessions: sessions, weekContaining: reference, calendar: calendar)
    }

    /// Recomputes the insight cards over the last `insightLookbackDays`. Insights
    /// are week-scale, so they're tied to the open instant, not the navigable
    /// ``day`` — `stepDay(by:)` does not refresh them.
    private func reloadInsights() async {
        let reference = now()
        let start = calendar.date(byAdding: .day, value: -insightLookbackDays, to: calendar.startOfDay(for: reference))
            ?? reference
        let sessions = (try? await repository.sessions(in: DateInterval(start: start, end: reference))) ?? []
        focusWindow = DashboardAnalytics.bestFocusWindow(
            sessions: sessions,
            endingAt: reference,
            calendar: calendar,
            lookbackDays: insightLookbackDays
        )
    }

    private func reloadTimeline() async {
        let dayStart = day
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return }
        let sessions = (try? await repository.sessions(in: DateInterval(start: dayStart, end: dayEnd))) ?? []
        // The day may have changed during the await (rapid chevron presses spawn
        // overlapping reloads that can resume out of order); commit only if this
        // load is still for the day on screen, so the last-requested day wins.
        guard dayStart == day else { return }
        // Calendar blocks aren't persisted, so they're only available for today.
        let blocks = calendar.isDate(dayStart, inSameDayAs: calendar.startOfDay(for: now())) ? todaysBlocks() : []
        timeline = DashboardAnalytics.dayTimeline(sessions: sessions, calendarBlocks: blocks, on: dayStart, calendar: calendar)
    }
}
