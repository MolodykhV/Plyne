import Foundation
import Observation
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

    private let repository: any SessionRepository
    private let now: @Sendable () -> Date
    private var tickTask: Task<Void, Never>?
    private var autoResetTask: Task<Void, Never>?

    /// The recent history window, loaded once per idle visit and ranked
    /// locally on each keystroke. Larger than the display limit so filtering
    /// by the draft still has candidates to surface.
    private var intentionHistory: [IntentionStat] = []
    private static let historyWindow = 50

    init(repository: any SessionRepository, now: @Sendable @escaping () -> Date = Date.init) {
        self.repository = repository
        self.now = now
        self.displayNow = now()
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

    // No deinit cleanup is needed: both owned tasks capture `self` weakly and
    // exit on their next wake (within ~1s) once the store deallocates.
}

/// The two modes offered in the idle picker. A plain `Hashable` enum without
/// associated values so a SwiftUI `Picker` can tag it; mapped to the domain
/// ``SessionMode`` with the configured defaults at start time.
enum PickerMode: CaseIterable, Identifiable {
    case pomodoro
    case flowmodoro

    var id: Self { self }

    var sessionMode: SessionMode {
        switch self {
        case .pomodoro:
            return .pomodoro(workMinutes: Pomodoro.defaultWorkMinutes, breakMinutes: Pomodoro.defaultBreakMinutes)
        case .flowmodoro:
            return .flowmodoro
        }
    }
}

private extension String {
    /// The trimmed string, or `nil` if it is empty once trimmed.
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
