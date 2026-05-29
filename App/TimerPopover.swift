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
    @FocusState private var intentionFocused: Bool

    var body: some View {
        @Bindable var store = store
        VStack(alignment: .leading, spacing: 12) {
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

            PrimaryButton("action.start") { store.start() }
                .frame(maxWidth: .infinity)
        }
        .onAppear {
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

// MARK: - Glass-aware action buttons

/// A prominent primary action. Uses Liquid Glass on the control layer, falling
/// back to a solid prominent button when the user has reduced transparency or
/// increased contrast (translucency they have opted out of).
private struct PrimaryButton: View {
    let titleKey: LocalizedStringKey
    let action: () -> Void
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    init(_ titleKey: LocalizedStringKey, action: @escaping () -> Void) {
        self.titleKey = titleKey
        self.action = action
    }

    private var solid: Bool { reduceTransparency || contrast == .increased }

    var body: some View {
        if solid {
            Button(titleKey, action: action).buttonStyle(.borderedProminent)
        } else {
            Button(titleKey, action: action).buttonStyle(.glassProminent)
        }
    }
}

/// A secondary action; glass when available, bordered otherwise.
private struct SecondaryButton: View {
    let titleKey: LocalizedStringKey
    let action: () -> Void
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    init(_ titleKey: LocalizedStringKey, action: @escaping () -> Void) {
        self.titleKey = titleKey
        self.action = action
    }

    private var solid: Bool { reduceTransparency || contrast == .increased }

    var body: some View {
        if solid {
            Button(titleKey, action: action).buttonStyle(.bordered)
        } else {
            Button(titleKey, action: action).buttonStyle(.glass)
        }
    }
}
