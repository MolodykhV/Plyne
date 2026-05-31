import SwiftUI

/// The first-run intro: three calm, factual screens (what Plyne is, the optional
/// calendar read, the keyboard shortcuts) ending in Done. No "let's start small"
/// or goal-setting prompts — the concept treats the user as an expert who
/// decides their own first step.
struct OnboardingView: View {
    /// Called when the user finishes the last screen; the window controller
    /// closes the window (and marks onboarding seen) in response.
    let onDone: () -> Void

    @State private var step = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // An instance computed value (not a static): three cheap items, and it keeps
    // shared mutable state out of the type under Swift 6 strict concurrency.
    private var steps: [OnboardingStep] {
        [
            OnboardingStep(symbol: "timer", title: "onboarding.intro.title", body: "onboarding.intro.body", kind: .text),
            OnboardingStep(symbol: "calendar", title: "onboarding.calendar.title", body: "onboarding.calendar.body", kind: .text),
            OnboardingStep(symbol: "command", title: "onboarding.hotkeys.title", body: "onboarding.hotkeys.body", kind: .hotkeys)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepBody
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: step)
            footer
        }
        .padding(24)
        .frame(width: 460, height: 430)
    }

    @ViewBuilder private var stepBody: some View {
        switch steps[step].kind {
        case .text:
            OnboardingTextStep(step: steps[step])
        case .hotkeys:
            OnboardingHotkeysStep(step: steps[step])
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            StepDots(count: steps.count, current: step)
            Spacer()
            if step > 0 {
                SecondaryButton("onboarding.back") { step -= 1 }
            }
            if step < steps.count - 1 {
                PrimaryButton("onboarding.next") { step += 1 }
            } else {
                PrimaryButton("action.done", action: onDone)
            }
        }
    }
}

/// One onboarding screen's content. Kept as data so the flow is a simple index.
private struct OnboardingStep: Identifiable {
    enum Kind { case text, hotkeys }

    let id = UUID()
    let symbol: String
    let title: LocalizedStringKey
    let body: LocalizedStringKey
    let kind: Kind
}

/// Heading + paragraph screen.
private struct OnboardingTextStep: View {
    let step: OnboardingStep

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            heading(step)
            Text(step.body)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The shortcuts screen: heading, one line of intro, then the live default
/// chords (read from `HotkeyAction`, so they can't drift from what's registered).
private struct OnboardingHotkeysStep: View {
    let step: OnboardingStep

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            heading(step)
            Text(step.body)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(HotkeyAction.allCases, id: \.self) { action in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(action.displayChord)
                            .font(.body.monospaced())
                            .frame(minWidth: 64, alignment: .leading)
                        Text(description(for: action))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.top, 4)
        }
    }

    private func description(for action: HotkeyAction) -> LocalizedStringKey {
        switch action {
        case .toggleSession: return "onboarding.hotkeys.toggleSession"
        case .toggleMode: return "onboarding.hotkeys.toggleMode"
        case .openDashboard: return "onboarding.hotkeys.openDashboard"
        }
    }
}

/// Shared screen heading: a neutral symbol and a header-trait title.
@ViewBuilder
private func heading(_ step: OnboardingStep) -> some View {
    Image(systemName: step.symbol)
        .font(.largeTitle)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
    Text(step.title)
        .font(.title2)
        .accessibilityAddTraits(.isHeader)
}

/// Unobtrusive progress dots (no motion — just a filled accent dot for the
/// current step). Announced to VoiceOver as "step N of M".
private struct StepDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == current ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("onboarding.progress \(current + 1) \(count)"))
    }
}
