import SwiftUI
import PlyneCore
import PlyneTimer

/// The menu-bar popover. A thin function of `store.state`: each state maps to
/// one calm pane. Liquid Glass is confined to the action buttons; everything
/// else sits on a plain background, per the concept's "glass on the control
/// layer only" rule.
struct TimerPopover: View {
    @Environment(PlyneStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            pane
                .transition(.opacity)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: store.state)

            if let notice = store.notice {
                NoticeRow(notice: notice) { store.dismissNotice() }
            }

            Divider()
            Footer()
        }
        .padding(16)
        .frame(width: 300)
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
}

// MARK: - Panes

private struct IdlePane: View {
    @Environment(PlyneStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var intentionFocused: Bool
    @State private var addingPastSession = false

    var body: some View {
        Group {
            if addingPastSession {
                RetroactiveEntryPane { addingPastSession = false }
            } else {
                startContent
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: addingPastSession)
    }

    private var startContent: some View {
        @Bindable var store = store
        let inMeeting = store.meetingNow != nil
        return VStack(alignment: .leading, spacing: 12) {
            // A meeting is on: state it plainly and offer manual start — never
            // block (concept: respect for autonomy).
            if inMeeting {
                Text("calendar.meeting_now.title")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Picker("mode.picker.label", selection: $store.draftMode) {
                Text("mode.pomodoro").tag(PickerMode.pomodoro)
                Text("mode.flowmodoro").tag(PickerMode.flowmodoro)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            TextField("intention.placeholder", text: $store.draftIntention)
                .textFieldStyle(.plain)
                .lineLimit(1)
                .focused($intentionFocused)
                .onSubmit { store.start() }

            if !store.suggestions.isEmpty {
                SuggestionList(suggestions: store.suggestions) { suggestion in
                    store.applySuggestion(suggestion)
                    // The tapped row is dropped from the re-ranked list (it now
                    // equals the draft), so its element is torn out; return
                    // focus to the field for keyboard/VoiceOver users.
                    DispatchQueue.main.async { intentionFocused = true }
                }
            }

            PrimaryButton(inMeeting ? "calendar.meeting_now.start" : "action.start") { store.start() }
                .frame(maxWidth: .infinity)

            // Only meaningful when there is typed text to ignore; otherwise the
            // primary Start already begins with no focus, so showing it would
            // just duplicate that button.
            if store.hasDraftIntention {
                Button("action.start_without_intention") { store.startWithoutIntention() }
                    .buttonStyle(.plain)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }

            CalendarConnectRow()

            Divider()

            Button("retro.add") { addingPastSession = true }
                .buttonStyle(.plain)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        // Smooth the popover's resize as suggestions filter in and out while
        // typing, per the concept's calm-motion rule; off under Reduce Motion.
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: store.suggestions)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: store.hasDraftIntention)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: inMeeting)
        .onAppear {
            store.loadIntentionHistory()
            // The popover window may not be key on open, so defer focus a
            // runloop turn. Typing may still require a first click on Tahoe.
            DispatchQueue.main.async { intentionFocused = true }
        }
    }
}

/// A short, tappable list of recent intentions. Selecting one fills the field
/// (the user can still edit before starting). Plain rows on the content layer
/// — no glass, no decoration — to keep the prompt calm.
private struct SuggestionList: View {
    let suggestions: [IntentionSuggestion]
    let onSelect: (IntentionSuggestion) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(suggestions, id: \.text) { suggestion in
                Button { onSelect(suggestion) } label: {
                    Text(suggestion.text)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .font(.callout)
                .foregroundStyle(.secondary)
                .accessibilityHint(Text("a11y.suggestion.hint"))
            }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TimeReadout(text: displayText, accessibility: spokenLabelKey)
            IntentionLine(intention: active.intention)
            HStack(spacing: 8) {
                PrimaryButton("action.end") { store.end() }
                SecondaryButton("action.discard") { store.discard() }
            }
        }
    }
}

private struct MainEndedPane: View {
    @Environment(PlyneStore.self) private var store
    let active: ActiveSession

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("session.bell.title")
                .font(.headline)
            IntentionLine(intention: active.intention)
            HStack(spacing: 8) {
                PrimaryButton("action.finish") { store.end() }
                SecondaryButton("action.keep_going") { store.keepGoing() }
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
        VStack(alignment: .leading, spacing: 12) {
            TimeReadout(
                text: DurationFormatting.clock(remaining),
                accessibility: "a11y.remaining \(DurationFormatting.spoken(remaining))"
            )
            IntentionLine(intention: active.intention)
            HStack(spacing: 8) {
                PrimaryButton("action.finish") { store.end() }
                SecondaryButton("action.discard") { store.discard() }
            }
        }
    }
}

private struct FinishedPane: View {
    @Environment(PlyneStore.self) private var store
    let session: Session

    private var summary: LocalizedStringKey {
        let minutes = DurationFormatting.wholeMinutes(session.duration ?? 0)
        if let intention = session.intention, !intention.isEmpty {
            return "session.summary.intention \(minutes) \(intention)"
        }
        return "session.summary.plain \(minutes)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(summary)
                .font(.callout)
            PrimaryButton("action.done") { store.reset() }
                .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Shared pieces

private struct TimeReadout: View {
    let text: String
    let accessibility: LocalizedStringResource

    var body: some View {
        Text(text)
            .font(.system(.largeTitle, design: .rounded))
            .monospacedDigit()
            .accessibilityLabel(Text(accessibility))
    }
}

private struct IntentionLine: View {
    let intention: String?

    var body: some View {
        if let intention, !intention.isEmpty {
            Text(intention)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }
}

private struct NoticeRow: View {
    let notice: PersistenceNotice
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(notice.messageKey)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Button("action.dismiss", action: dismiss)
                .buttonStyle(.plain)
                .font(.footnote)
        }
    }
}

private struct Footer: View {
    var body: some View {
        Button("menubar.quit") { NSApplication.shared.terminate(nil) }
            .buttonStyle(.plain)
            .keyboardShortcut("q")
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
