import Foundation
import Observation
import PlyneCalendar
import PlyneCore
import PlyneTimer

/// The single source of UI truth for the timer.
///
/// `PlyneStore` is the only stateful, MainActor-isolated layer. It funnels
/// every ``TimerEvent`` through the pure ``FocusTimer`` reducer, owns the
/// 1-second tick that keeps the menu-bar icon live even while the popover is
/// closed, and persists a finished session to the repository actor — never
/// throwing into the UI. The reducer stays pure; all side effects live here,
/// keyed off the state transition.
@MainActor
@Observable
final class PlyneStore {
    /// The current finite state.
    private(set) var state: TimerState = FocusTimer.initialState

    /// The instant the UI should render against, refreshed each tick. Drives
    /// both the menu-bar progress and the popover countdown from one clock,
    /// so there is no second timer to keep in sync.
    private(set) var displayNow: Date

    /// A calm, dismissable notice when a background action could not complete
    /// (e.g. a session could not be saved). Surfaced, never thrown.
    private(set) var notice: PersistenceNotice?

    /// Draft mode for the idle screen's picker. Held here (not in the reducer)
    /// so the control is a plain binding; folded into `.prepare` on start.
    var draftMode: PickerMode = .pomodoro

    /// Draft intention text for the idle screen's field.
    var draftIntention: String = "" {
        didSet { refreshSuggestions() }
    }

    /// Suggestions for the idle prompt, ranked against `draftIntention`.
    /// Recomputed from the in-memory history window — no per-keystroke fetch.
    private(set) var suggestions: [IntentionSuggestion] = []

    /// How many suggestions the prompt shows at once.
    static let suggestionLimit = 6

    /// Whether the draft holds anything once trimmed. Drives the optional
    /// "start without naming a focus" escape hatch, which only makes sense
    /// when there is typed text to ignore.
    var hasDraftIntention: Bool {
        !draftIntention.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Calendar read access, as Plyne sees it. Drives the idle screen's
    /// connect affordance vs the during-meeting hint. `.notDetermined` until
    /// the first status read completes.
    private(set) var calendarAuthorization: CalendarAuthorization = .notDetermined

    /// Today's calendar blocks, refreshed every few minutes while authorized.
    private(set) var todaysBlocks: [CalendarBlock] = []

    /// The meeting active right now, if any. Computed against `displayNow`, so
    /// it stays fresh as the tick advances — only a `.meeting` suppresses the
    /// timer suggestion.
    var meetingNow: CalendarBlock? { MeetingNow.active(in: todaysBlocks, at: displayNow) }

    /// Set by the app delegate to open the dashboard window — invoked from the
    /// popover button (the global hotkey calls the window controller directly).
    /// `@ObservationIgnored`: it's an action hook, not rendered state.
    @ObservationIgnored var openDashboard: (() -> Void)?

    private let repository: any SessionRepository
    private let calendar: any CalendarReading
    private let now: @Sendable () -> Date
    private var tickTask: Task<Void, Never>?
    private var autoResetTask: Task<Void, Never>?
    private var calendarTask: Task<Void, Never>?
    private static let calendarRefreshSeconds: UInt64 = 300

    /// The recent history window, loaded once per idle visit and ranked
    /// locally on each keystroke. Larger than the display limit so filtering
    /// by the draft still has candidates to surface.
    private var intentionHistory: [IntentionStat] = []
    private static let historyWindow = 50

    init(
        repository: any SessionRepository,
        calendar: any CalendarReading = EventKitCalendarReader(),
        now: @Sendable @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.calendar = calendar
        self.now = now
        self.displayNow = now()
        // Read current access WITHOUT prompting; if already granted in a prior
        // session, begin polling. The opt-in prompt is only `connectCalendar()`.
        Task { [weak self] in
            guard let self else { return }
            let status = await self.calendar.authorizationStatus()
            self.calendarAuthorization = status
            if status == .authorized { self.startCalendarPolling() }
        }
    }

    // MARK: - Single entry point

    /// Applies `event` through the reducer and runs any side effects implied
    /// by the resulting transition.
    func dispatch(_ event: TimerEvent) {
        let old = state
        let new = FocusTimer.reduce(old, on: event)
        guard new != old else { return }
        state = new
        react(from: old, to: new)
    }

    // MARK: - Intent-level convenience (the views call these)

    /// Folds the idle draft into a prepared, started session.
    func start() {
        let intention = draftIntention.trimmedNonEmpty
        dispatch(.prepare(mode: draftMode.sessionMode, intention: intention))
        dispatch(.start(now: now()))
    }

    /// Starts with no intention, ignoring whatever is in the draft. The
    /// prompt is optional by design — naming a task is never an obligation.
    func startWithoutIntention() {
        draftIntention = ""
        dispatch(.prepare(mode: draftMode.sessionMode, intention: nil))
        dispatch(.start(now: now()))
    }

    /// Fills the draft from a chosen suggestion (does not start — the user
    /// can still edit, then start). Re-ranks against the new text.
    func applySuggestion(_ suggestion: IntentionSuggestion) {
        draftIntention = suggestion.text
    }

    /// Loads the recent intention history for the idle prompt. Called when
    /// the idle pane appears; cheap and idempotent.
    func loadIntentionHistory() {
        Task { [repository] in
            let window = Self.historyWindow
            let stats = (try? await repository.recentIntentionStats(limit: window)) ?? []
            await MainActor.run {
                self.intentionHistory = stats
                self.refreshSuggestions()
            }
        }
    }

    /// Ends the in-flight session (running / mainEnded / overflow).
    func end() { dispatch(.end(now: now())) }

    /// One-key start/stop for the global hotkey: ends an in-flight session,
    /// otherwise starts one. From a terminal summary it resets to idle first
    /// (no draft to preserve there) so the next press starts cleanly; from
    /// idle it preserves any intention typed in the popover.
    func toggleSession() {
        switch state {
        case .running, .mainEnded, .overflow:
            end()
        case .finished, .abandoned:
            reset()
            start()
        case .idle:
            start()
        case .preparing:
            // Already prepared (mode + intention chosen); start that payload
            // directly. Routing through start() would re-dispatch .prepare,
            // which is a no-op from .preparing, so it must not be relied on.
            dispatch(.start(now: now()))
        }
    }

    /// Flips the idle picker between Pomodoro and Flowmodoro. Mode is chosen
    /// before a session starts, so this takes effect on the next start.
    func toggleDraftMode() {
        draftMode = draftMode == .pomodoro ? .flowmodoro : .pomodoro
    }

    /// Extends a main-ended Pomodoro into an overflow window.
    func keepGoing(minutes: Int = Overflow.defaultMinutes) {
        dispatch(.beginOverflow(now: now(), minutes: Overflow.clampedMinutes(minutes)))
    }

    // MARK: - Retroactive entry (a session added after the fact)

    /// Adds a session that already happened. Independent of the live FSM —
    /// the timer's state is untouched.
    ///
    /// Overlap with existing sessions is a *warning*, not an error (concept:
    /// respect for autonomy): the first call that would overlap returns
    /// `.overlap` without saving; call again with `force: true` to record it
    /// anyway. Invalid inputs (non-positive duration, reversed interval)
    /// return `.invalid`.
    func addRetroactiveSession(
        startedAt: Date,
        durationMinutes: Int,
        mode: PickerMode,
        intention: String?,
        force: Bool = false
    ) async -> RetroactiveOutcome {
        guard durationMinutes > 0 else { return .invalid }
        let endedAt = startedAt.addingTimeInterval(TimeInterval(durationMinutes) * 60)
        let trimmed = intention?.trimmedNonEmpty

        let session: Session
        do {
            session = try FocusTimer.retroactiveSession(
                startedAt: startedAt,
                endedAt: endedAt,
                mode: mode.sessionMode,
                intention: trimmed
            )
        } catch {
            return .invalid
        }

        if !force {
            // Query a window wide enough to catch a session that began before
            // the candidate but runs into it. A day's lead covers any
            // realistic focus session; the pure overlap check is exact, and a
            // missed warning only means no prompt — the save is still correct.
            let window = DateInterval(
                start: startedAt.addingTimeInterval(-86_400),
                end: endedAt.addingTimeInterval(60)
            )
            let existing = (try? await repository.sessions(in: window)) ?? []
            let overlaps = SessionOverlap.overlapping(start: startedAt, end: endedAt, in: existing)
            if !overlaps.isEmpty { return .overlap(count: overlaps.count) }
        }

        do {
            try await repository.save(session)
            if let trimmed { try? await repository.recordIntention(trimmed, at: startedAt) }
            return .added
        } catch {
            notice = .couldNotSave
            return .notSaved
        }
    }

    /// Throws the in-flight session away without recording it, then returns
    /// to idle. The reducer's `.discard` lands in the terminal `.abandoned`
    /// state, which the UI never rests in — `reset()` immediately moves it
    /// back to idle (and clears the draft) so the user can start again.
    func discard() {
        dispatch(.discard)
        reset()
    }

    /// Returns to idle (also dismisses a finished summary).
    func reset() {
        draftIntention = ""
        dispatch(.reset)
    }

    /// Clears the current notice.
    func dismissNotice() { notice = nil }

    // MARK: - Calendar (read-only, explicit opt-in)

    /// Requests calendar access — only from the explicit "Connect calendar"
    /// action, never at launch. On grant, begins the refresh poll.
    func connectCalendar() {
        Task { [weak self] in
            guard let self else { return }
            let status = await self.calendar.requestAccess()
            self.calendarAuthorization = status
            if status == .authorized { self.startCalendarPolling() }
        }
    }

    private func startCalendarPolling() {
        guard calendarTask == nil else { return }
        calendarTask = Task { [weak self] in
            while !Task.isCancelled {
                // `self` is acquired only for the refresh, then released before
                // the long sleep, so the store isn't pinned alive for a whole
                // interval after the UI drops it. A `nil` self (store gone) or a
                // `false` return (access lost) ends the loop.
                guard let keepPolling = await self?.refreshCalendarOnce(), keepPolling else { return }
                try? await Task.sleep(for: .seconds(Double(Self.calendarRefreshSeconds)))
            }
        }
    }

    /// One calendar refresh. Re-reads authorization (so a mid-run revoke in
    /// System Settings is noticed): on loss it clears today's blocks, drops the
    /// poll task so a later ``connectCalendar()`` can re-arm it, and returns
    /// `false` to stop. Otherwise refreshes ``todaysBlocks`` and returns `true`.
    private func refreshCalendarOnce() async -> Bool {
        let status = await calendar.authorizationStatus()
        calendarAuthorization = status
        guard status == .authorized else {
            todaysBlocks = []
            calendarTask = nil
            return false
        }
        let events = await calendar.todaysEvents(now: now())
        todaysBlocks = CalendarBlockMapper.blocks(from: events)
        return true
    }

    /// Re-ranks the in-memory history against the current draft.
    private func refreshSuggestions() {
        suggestions = IntentionRanker.rank(
            intentionHistory,
            query: draftIntention,
            now: now(),
            limit: Self.suggestionLimit
        )
    }

    // MARK: - Side effects, keyed off the transition

    private func react(from old: TimerState, to new: TimerState) {
        if case let .finished(session) = new {
            persist(session)
            if let text = session.intention?.trimmedNonEmpty { recordIntention(text) }
            scheduleAutoReset()
        }

        if new.isInFlight {
            startTicking()
        } else {
            stopTicking()
        }

        if case .idle = new { autoResetTask?.cancel(); autoResetTask = nil }
    }

    // MARK: - Tick loop (store-owned so the icon stays live with the popover closed)

    private func startTicking() {
        guard tickTask == nil else { return }
        displayNow = now()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, self.state.isInFlight else {
                    self?.stopTicking()
                    return
                }
                let instant = self.now()
                self.displayNow = instant
                self.dispatch(.tick(now: instant))
            }
        }
    }

    private func stopTicking() {
        tickTask?.cancel()
        tickTask = nil
    }

    // MARK: - finished -> idle (hold, dismiss on tap, with a safety net)

    private func scheduleAutoReset() {
        autoResetTask?.cancel()
        autoResetTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(9))
            guard let self, case .finished = self.state else { return }
            self.reset()
        }
    }

    // MARK: - Persistence (capture the Sendable repo; hop to self only for UI)

    private func persist(_ session: Session) {
        Task { [repository] in
            do {
                try await repository.save(session)
            } catch {
                await MainActor.run { self.notice = .couldNotSave }
            }
        }
    }

    private func recordIntention(_ text: String) {
        Task { [repository, now] in
            try? await repository.recordIntention(text, at: now())
        }
    }

    // No deinit cleanup is needed: every owned task (tick, auto-reset, and the
    // calendar poll) captures `self` weakly and holds no strong reference across
    // its sleep, so the store deallocates promptly; each orphaned task then ends
    // on its next wake when it finds `self` gone.
}
