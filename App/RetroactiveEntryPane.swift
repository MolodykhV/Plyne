import SwiftUI
import PlyneCore

/// Adds a session that already happened (the user forgot to start the timer).
/// Overlap with existing sessions is surfaced as a calm warning, not a block —
/// the user may record it anyway, per the concept's respect for autonomy.
///
/// Laid out as the design's labeled-row form: a title, then Started / Duration
/// / Mode rows (label left, control right), the focus field, and Cancel + Add.
struct RetroactiveEntryPane: View {
    @Environment(PlyneStore.self) private var store
    let onClose: () -> Void

    @State private var startedAt = Date.now.addingTimeInterval(-3600)
    @State private var durationMinutes = Pomodoro.defaultWorkMinutes
    @State private var mode: PickerMode = .pomodoro
    @State private var intention = ""
    @State private var overlapWarned = false
    @State private var submitting = false
    @FocusState private var intentionFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: PlyneSpacing.s3) {
            Text("retro.title")
                .font(.plyneSection)

            // Inputs are disabled while a submit is in flight: editing the
            // start/duration would fire the .onChange handlers below and clear
            // a just-returned overlap warning, racing the async result.
            Group {
                LabeledRow("retro.when") {
                    DatePicker("retro.when", selection: $startedAt, in: ...Date.now)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                }
                LabeledRow("retro.label.duration") {
                    DurationStepper(minutes: $durationMinutes, range: 5...600, step: 5)
                }
                LabeledRow("retro.label.mode") {
                    ModeSegmented(selection: $mode, fillsWidth: false)
                }

                TextField("intention.placeholder", text: $intention)
                    .lineLimit(1)
                    .focused($intentionFocused)
                    .plyneField(focused: intentionFocused)
            }
            .disabled(submitting)

            if overlapWarned {
                HStack(spacing: PlyneSpacing.s2) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text("retro.overlap")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, PlyneSpacing.s2)
                .padding(.horizontal, PlyneSpacing.s3)
                .plyneTile(cornerRadius: PlyneRadius.sm)
            }

            // Secondary on the left, primary on the right — the popover's
            // convention across every two-action pane.
            HStack(spacing: PlyneSpacing.s2) {
                SecondaryButton("action.cancel") { onClose() }
                PrimaryButton(overlapWarned ? "retro.save_anyway" : "retro.save") {
                    submit(force: overlapWarned)
                }
                .disabled(submitting)
                // The warning Text is inserted above and a button relabel isn't
                // auto-spoken, so VoiceOver users get the "why" from the hint
                // (plus the announcement posted in submit()).
                .accessibilityHint(overlapWarned ? Text("retro.overlap") : Text(verbatim: ""))
            }
        }
        // A change to the inputs invalidates any standing overlap warning.
        .onChange(of: startedAt) { overlapWarned = false }
        .onChange(of: durationMinutes) { overlapWarned = false }
    }

    private func submit(force: Bool) {
        submitting = true
        Task {
            let outcome = await store.addRetroactiveSession(
                startedAt: startedAt,
                durationMinutes: durationMinutes,
                mode: mode,
                intention: intention,
                force: force
            )
            submitting = false
            switch outcome {
            case .added:
                onClose()
            case .overlap:
                overlapWarned = true
                // The tap did not save; speak the reason so a VoiceOver user
                // can consciously choose "Add anyway" (the step's autonomy
                // premise) rather than meeting silence.
                AccessibilityNotification.Announcement(String(localized: "retro.overlap")).post()
            case .invalid, .notSaved:
                break
            }
        }
    }
}

/// One form row: a quiet label on the left, its control trailing-aligned.
private struct LabeledRow<Control: View>: View {
    let labelKey: LocalizedStringKey
    @ViewBuilder let control: Control

    init(_ labelKey: LocalizedStringKey, @ViewBuilder control: () -> Control) {
        self.labelKey = labelKey
        self.control = control()
    }

    var body: some View {
        HStack(spacing: PlyneSpacing.s3) {
            Text(labelKey)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer(minLength: PlyneSpacing.s2)
            control
        }
    }
}

/// A frosted "− 25 min +" stepper matching the design (a control-layer surface
/// with a solid fallback under Reduce Transparency / Increase Contrast). Reuses
/// the existing `retro.duration` string for the value, so no new copy.
private struct DurationStepper: View {
    @Binding var minutes: Int
    let range: ClosedRange<Int>
    let step: Int

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: PlyneRadius.sm, style: .continuous) }

    var body: some View {
        HStack(spacing: 0) {
            stepButton("minus") { set(minutes - step) }
            Text("retro.duration \(minutes)")
                .font(.system(size: 13, weight: .medium).monospacedDigit())
                .frame(minWidth: 56)
            stepButton("plus") { set(minutes + step) }
        }
        .background(shape.fill(reduceTransparency ? AnyShapeStyle(Color.primary.opacity(0.06)) : AnyShapeStyle(.thinMaterial)))
        .overlay(shape.strokeBorder(Color.primary.opacity(contrast == .increased ? 0.28 : 0.12), lineWidth: 1))
        .accessibilityElement()
        .accessibilityLabel(Text("retro.label.duration"))
        .accessibilityValue(Text("retro.duration \(minutes)"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: set(minutes + step)
            case .decrement: set(minutes - step)
            default: break
            }
        }
    }

    private func set(_ value: Int) {
        minutes = min(range.upperBound, max(range.lowerBound, value))
    }

    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .accessibilityHidden(true)
    }
}
