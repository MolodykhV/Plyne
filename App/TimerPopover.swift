import SwiftUI
import PlyneCore
import PlyneTimer

/// The menu-bar popover. A thin function of `store.state`: each state maps to
/// one calm pane. Liquid Glass / material stays on the control layer (buttons,
/// fields, chips); content sits on the popover's own background, warmed only by
/// the faint brand-wave crown and accent washes, per the concept's "glass on
/// the control layer only" rule.
struct TimerPopover: View {
    @Environment(PlyneStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: PlyneSpacing.s4) {
            // The panes overlap in a ZStack so a swap CROSS-DISSOLVES (a VStack
            // would briefly stack the two panes vertically and mask it). The
            // `.animation` lives on this stable parent — not on the id'd child —
            // which is what actually drives the child's insert/remove transition.
            ZStack(alignment: .topLeading) {
                pane
                    // A stable per-pane identity so the swap is a clean
                    // insert/remove (and the transition fires) on a real pane
                    // change, never on a tick.
                    .id(paneKey)
                    .transition(.plynePane)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(reduceMotion ? nil : PlyneMotion.ease(PlyneMotion.slow), value: paneKey)

            if let notice = store.notice {
                NoticeRow(notice: notice) { store.dismissNotice() }
                    .transition(.plynePane)
            }

            Divider()
            Footer()
        }
        .padding(PlyneSpacing.s4)
        .frame(width: 300)
        .animation(reduceMotion ? nil : PlyneMotion.ease(), value: store.notice != nil)
        // A whisper of the brand wave at the very top — it should sit *behind*
        // the content, not wash it; the design keeps it barely-there over the
        // translucent popover. Hidden entirely under Reduce Transparency.
        .plyneCrown(height: 104, opacity: 0.15)
    }

    @ViewBuilder
    private var pane: some View {
        switch store.state {
        case .idle, .preparing, .abandoned:
            IdlePane()
        case let .running(active):
            RunningPane(active: active)
        case let .mainEnded(active):
            MainEndedPane(active: active)
        case let .overflow(active, until):
            OverflowPane(active: active, until: until)
        case let .finished(session):
            FinishedPane(session: session)
        }
    }

    /// One key per pane *kind* — idle/preparing/abandoned all read as "idle",
    /// so the cross-dissolve fires only on a genuine pane change.
    private var paneKey: String {
        switch store.state {
        case .idle, .preparing, .abandoned: return "idle"
        case .running: return "running"
        case .mainEnded: return "mainEnded"
        case .overflow: return "overflow"
        case .finished: return "finished"
        }
    }
}

// MARK: - Panes

private struct IdlePane: View {
    @Environment(PlyneStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var intentionFocused: Bool
    @State private var addingPastSession = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            if addingPastSession {
                RetroactiveEntryPane { addingPastSession = false }
                    .transition(.plynePane)
            } else {
                startContent
                    .transition(.plynePane)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(reduceMotion ? nil : PlyneMotion.ease(PlyneMotion.slow), value: addingPastSession)
    }

    private var startContent: some View {
        @Bindable var store = store
        let inMeeting = store.meetingNow != nil
        return VStack(alignment: .leading, spacing: PlyneSpacing.s4) {
            // A meeting is on: state it plainly and offer manual start — never
            // block (concept: respect for autonomy).
            if inMeeting {
                MeetingHint()
            }

            ModeSegmented(selection: $store.draftMode)

            // The intention + its recent suggestions read as one group: the
            // visual lead of this pane.
            VStack(alignment: .leading, spacing: PlyneSpacing.s2) {
                TextField("intention.placeholder", text: $store.draftIntention)
                    .focused($intentionFocused)
                    .plyneField(focused: intentionFocused, big: true)
                    .onSubmit { store.start() }

                if !store.suggestions.isEmpty {
                    IntentionChips(titles: store.suggestions.map(\.text)) { index in
                        // Index into the live list defensively: history can be
                        // re-ranked asynchronously between render and tap.
                        guard index < store.suggestions.count else { return }
                        store.applySuggestion(store.suggestions[index])
                        // The tapped row is re-ranked out of the list; return
                        // focus to the field for keyboard/VoiceOver users.
                        DispatchQueue.main.async { intentionFocused = true }
                    }
                    .accessibilityHint(Text("a11y.suggestion.hint"))
                }
            }

            VStack(spacing: PlyneSpacing.s2) {
                PrimaryButton(inMeeting ? "calendar.meeting_now.start" : "action.start") { store.start() }
                    .frame(maxWidth: .infinity)

                // Only meaningful when there is typed text to ignore; otherwise
                // the primary Start already begins with no focus.
                if store.hasDraftIntention {
                    HStack {
                        Spacer(minLength: 0)
                        PlyneTextButton("action.start_without_intention") { store.startWithoutIntention() }
                        Spacer(minLength: 0)
                    }
                }
            }

            Divider()

            CalendarConnectRow()

            Divider()

            HStack {
                PlyneTextButton("retro.add", systemImage: "clock.arrow.circlepath") {
                    addingPastSession = true
                }
                Spacer(minLength: PlyneSpacing.s2)
                PlyneTextButton("dashboard.open", systemImage: "square.grid.2x2") {
                    store.openDashboard?()
                }
            }
        }
        // Smooth the popover's resize as suggestions filter in and out while
        // typing, per the concept's calm-motion rule; off under Reduce Motion.
        .animation(reduceMotion ? nil : PlyneMotion.ease(), value: store.suggestions)
        .animation(reduceMotion ? nil : PlyneMotion.ease(), value: store.hasDraftIntention)
        .animation(reduceMotion ? nil : PlyneMotion.ease(), value: inMeeting)
        .onAppear {
            store.loadIntentionHistory()
            // The popover window may not be key on open, so defer focus a
            // runloop turn. Typing may still require a first click on Tahoe.
            DispatchQueue.main.async { intentionFocused = true }
        }
    }
}

private struct RunningPane: View {
    @Environment(PlyneStore.self) private var store
    let active: ActiveSession

    private var displayText: String {
        if let workEnd = active.pomodoroWorkEnd {
            return DurationFormatting.clock(workEnd.timeIntervalSince(store.displayNow))
        }
        return DurationFormatting.clock(store.displayNow.timeIntervalSince(active.startedAt))
    }

    private var spokenLabelKey: LocalizedStringResource {
        if let workEnd = active.pomodoroWorkEnd {
            return "a11y.remaining \(DurationFormatting.spoken(workEnd.timeIntervalSince(store.displayNow)))"
        }
        return "a11y.elapsed \(DurationFormatting.spoken(store.displayNow.timeIntervalSince(active.startedAt)))"
    }

    /// Tells the sighted user whether the number counts down (Pomodoro) or up
    /// (Flowmodoro). VoiceOver hears the same via the spoken label above.
    private var readoutSub: LocalizedStringKey {
        active.pomodoroWorkEnd != nil ? "timer.readout.remaining" : "timer.readout.elapsed"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PlyneSpacing.s4) {
            TimeReadout(text: displayText, accessibility: spokenLabelKey, sub: readoutSub)
            IntentionPill(intention: active.intention)
            HStack(spacing: PlyneSpacing.s2) {
                SecondaryButton("action.discard") { store.discard() }
                    .frame(maxWidth: .infinity)
                PrimaryButton("action.end") { store.end() }
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct MainEndedPane: View {
    @Environment(PlyneStore.self) private var store
    let active: ActiveSession

    var body: some View {
        VStack(alignment: .center, spacing: PlyneSpacing.s4) {
            VStack(spacing: PlyneSpacing.s3) {
                PlyneGauge(phase: .ended, tint: .accentColor, lineWidth: 2)
                    .frame(width: 40, height: 40)
                    .accessibilityHidden(true)
                Text("session.bell.title")
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)

            IntentionPill(intention: active.intention)

            HStack(spacing: PlyneSpacing.s2) {
                SecondaryButton("action.keep_going") { store.keepGoing() }
                    .frame(maxWidth: .infinity)
                PrimaryButton("action.finish") { store.end() }
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct OverflowPane: View {
    @Environment(PlyneStore.self) private var store
    let active: ActiveSession
    let until: Date

    private var remaining: TimeInterval { until.timeIntervalSince(store.displayNow) }

    var body: some View {
        VStack(alignment: .leading, spacing: PlyneSpacing.s4) {
            TimeReadout(
                text: DurationFormatting.clock(remaining),
                accessibility: "a11y.remaining \(DurationFormatting.spoken(remaining))",
                sub: "timer.readout.overflow",
                accent: true
            )
            IntentionPill(intention: active.intention)
            HStack(spacing: PlyneSpacing.s2) {
                SecondaryButton("action.discard") { store.discard() }
                    .frame(maxWidth: .infinity)
                PrimaryButton("action.finish") { store.end() }
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct FinishedPane: View {
    @Environment(PlyneStore.self) private var store
    let session: Session

    private var summary: LocalizedStringKey {
        let minutes = DurationFormatting.minutesPhrase(session.duration ?? 0)
        if let intention = session.intention, !intention.isEmpty {
            return "session.summary.intention \(minutes) \(intention)"
        }
        return "session.summary.plain \(minutes)"
    }

    var body: some View {
        VStack(alignment: .center, spacing: PlyneSpacing.s4) {
            Text(summary)
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, PlyneSpacing.s2)
            PrimaryButton("action.done") { store.reset() }
                .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Shared pieces

/// The neutral "a meeting is on now" hint shown in Idle during a meeting.
private struct MeetingHint: View {
    var body: some View {
        HStack(spacing: PlyneSpacing.s2) {
            Image(systemName: "person.2")
                .font(.callout)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("calendar.meeting_now.title")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.vertical, PlyneSpacing.s2)
        .padding(.horizontal, PlyneSpacing.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .plyneTile(cornerRadius: PlyneRadius.sm)
        .accessibilityElement(children: .combine)
    }
}

private struct NoticeRow: View {
    let notice: PersistenceNotice
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: PlyneSpacing.s2) {
            Image(systemName: "info.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(notice.messageKey)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Button("action.dismiss", action: dismiss)
                .buttonStyle(.plain)
                .font(.footnote)
        }
        .padding(.vertical, PlyneSpacing.s2)
        .padding(.horizontal, PlyneSpacing.s3)
        .plyneTile(cornerRadius: PlyneRadius.sm)
    }
}

/// The shell's persistent bottom strip: a quiet "Welcome guide" (re-opens the
/// intro on demand) on the left and "Quit Plyne" on the right, with a hairline
/// above (drawn by the caller).
private struct Footer: View {
    @Environment(PlyneStore.self) private var store

    var body: some View {
        HStack {
            PlyneTextButton("onboarding.reopen", systemImage: "questionmark.circle") {
                store.openOnboarding?()
            }
            Spacer(minLength: PlyneSpacing.s2)
            PlyneTextButton("menubar.quit") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}
