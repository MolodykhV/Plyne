import SwiftUI
import PlyneCore

/// Adds a session that already happened (the user forgot to start the timer).
/// Overlap with existing sessions is surfaced as a calm warning, not a block —
/// the user may record it anyway, per the concept's respect for autonomy.
struct RetroactiveEntryPane: View {
    @Environment(PlyneStore.self) private var store
    let onClose: () -> Void

    @State private var startedAt = Date.now.addingTimeInterval(-3600)
    @State private var durationMinutes = Pomodoro.defaultWorkMinutes
    @State private var mode: PickerMode = .pomodoro
    @State private var intention = ""
    @State private var overlapWarned = false
    @State private var submitting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("retro.title")
                .font(.headline)

            // Inputs are disabled while a submit is in flight: editing the
            // start/duration would fire the .onChange handlers below and clear
            // a just-returned overlap warning, racing the async result.
            Group {
                DatePicker("retro.when", selection: $startedAt, in: ...Date.now)
                    .datePickerStyle(.compact)

                Stepper(value: $durationMinutes, in: 5...600, step: 5) {
                    Text("retro.duration \(durationMinutes)")
                }

                Picker("mode.picker.label", selection: $mode) {
                    Text("mode.pomodoro").tag(PickerMode.pomodoro)
                    Text("mode.flowmodoro").tag(PickerMode.flowmodoro)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                TextField("intention.placeholder", text: $intention)
                    .textFieldStyle(.plain)
                    .lineLimit(1)
            }
            .disabled(submitting)

            if overlapWarned {
                Text("retro.overlap")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                PrimaryButton(overlapWarned ? "retro.save_anyway" : "retro.save") {
                    submit(force: overlapWarned)
                }
                .disabled(submitting)
                // The warning Text is inserted below the focus point and a
                // button relabel isn't auto-spoken, so VoiceOver users get the
                // "why" from the button's hint (plus the announcement posted
                // in submit()).
                .accessibilityHint(overlapWarned ? Text("retro.overlap") : Text(verbatim: ""))
                SecondaryButton("action.cancel") { onClose() }
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
