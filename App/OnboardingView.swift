import SwiftUI

/// The first-run intro: three calm, factual screens (what Plyne is, the optional
/// calendar read, the keyboard shortcuts) ending in Done. No "let's start small"
/// or goal-setting prompts — the concept treats the user as an expert who
/// decides their own first step. A faint brand-wave crown and a confident
/// heading set the app's warm-but-calm tone from the first screen.
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
        VStack(spacing: 0) {
            stepBody
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(reduceMotion ? nil : PlyneMotion.ease(), value: step)
            footer
        }
        .padding(.horizontal, PlyneSpacing.s6)
        .padding(.bottom, PlyneSpacing.s6)
        // Clear the floating traffic lights (headless window, no title bar).
        .padding(.top, GlassWindow.trafficLightInset)
        .frame(width: 460, height: 430)
        // A faint brand-wave whisper at the top — behind the content, never
        // washing it (matches the popover and dashboard).
        .plyneCrown(height: 150, opacity: 0.15)
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
        HStack {
            // Fixed side zones keep the centred progress dots from shifting as
            // Back appears/disappears.
            ZStack(alignment: .leading) {
                if step > 0 {
                    PlyneTextButton("onboarding.back", systemImage: "chevron.left") { step -= 1 }
                }
            }
            .frame(width: 88, alignment: .leading)

            Spacer()
            StepDots(count: steps.count, current: step)
            Spacer()

            ZStack(alignment: .trailing) {
                if step < steps.count - 1 {
                    PrimaryButton("onboarding.next") { step += 1 }
                } else {
                    PrimaryButton("action.done", action: onDone)
                }
            }
            .frame(width: 88, alignment: .trailing)
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

/// Heading + paragraph screen, centred.
private struct OnboardingTextStep: View {
    let step: OnboardingStep

    var body: some View {
        VStack(spacing: PlyneSpacing.s4) {
            heading(step)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The shortcuts screen: heading, one line of intro, then the live default
/// chords (read from `HotkeyAction`, so they can't drift from what's registered).
private struct OnboardingHotkeysStep: View {
    let step: OnboardingStep

    var body: some View {
        VStack(spacing: PlyneSpacing.s4) {
            heading(step)
            VStack(alignment: .leading, spacing: PlyneSpacing.s3) {
                ForEach(HotkeyAction.allCases, id: \.self) { action in
                    HStack(spacing: PlyneSpacing.s3) {
                        Text(description(for: action))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: PlyneSpacing.s3)
                        HStack(spacing: PlyneSpacing.s1) {
                            ForEach(Array(action.displayChord.enumerated()), id: \.offset) { _, key in
                                PlyneKeyCap(label: String(key))
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Text(description(for: action)))
                    .accessibilityValue(Text(action.displayChord))
                }
            }
            .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func description(for action: HotkeyAction) -> LocalizedStringKey {
        switch action {
        case .toggleSession: return "onboarding.hotkeys.toggleSession"
        case .toggleMode: return "onboarding.hotkeys.toggleMode"
        case .openDashboard: return "onboarding.hotkeys.openDashboard"
        }
    }
}

/// Shared screen heading: a quiet symbol tile, a confident title, and the body.
@ViewBuilder
private func heading(_ step: OnboardingStep) -> some View {
    PlyneSymbolTile(symbol: step.symbol)
    Text(step.title)
        .font(.plyneTitle)
        .multilineTextAlignment(.center)
        .accessibilityAddTraits(.isHeader)
    Text(step.body)
        .font(.body)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 340)
}

/// Unobtrusive progress dots: the current step is an elongated accent capsule,
/// the rest neutral. Announced to VoiceOver as "step N of M".
private struct StepDots: View {
    let count: Int
    let current: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: PlyneSpacing.s2 - 1) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: index == current ? 18 : 7, height: 7)
            }
        }
        .animation(reduceMotion ? nil : PlyneMotion.ease(), value: current)
        .accessibilityElement()
        .accessibilityLabel(Text("onboarding.progress \(current + 1) \(count)"))
    }
}
