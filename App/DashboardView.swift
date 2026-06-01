import PlyneAnalytics
import SwiftUI

/// The dashboard window: this week's focus heatmap on top, an optional calm
/// observation, then the selected day's timeline. Stacked sections (no tabs —
/// they'd hide context), with a faint brand-wave crown for warmth. Reads its
/// data from ``DashboardModel``.
struct DashboardView: View {
    @Environment(DashboardModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PlyneSpacing.s6) {
                weekSection
                if let focusWindow = model.focusWindow {
                    InsightCardsView(focusWindow: focusWindow)
                }
                daySection
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            // Top inset clears the floating traffic lights (no title bar); the
            // generous top space matches the approved design.
            .padding(.top, GlassWindow.trafficLightInset + 16)
            .padding(.horizontal, PlyneSpacing.s5)
            .padding(.bottom, PlyneSpacing.s6)
        }
        .frame(minWidth: 420, minHeight: 520)
        // A faint brand-wave whisper at the top — it should sit behind the
        // content, never wash it (matches the popover's restraint).
        .plyneCrown(height: 140, opacity: 0.15)
        // Data load is triggered by DashboardWindowController.show() on every
        // open (the window is reused, so onAppear wouldn't fire on reopen).
    }

    private var weekSection: some View {
        VStack(alignment: .leading, spacing: PlyneSpacing.s3) {
            sectionHeader("dashboard.section.week")
            if let heatmap = model.weekHeatmap {
                WeekHeatmapView(heatmap: heatmap)
            }
        }
    }

    private var daySection: some View {
        VStack(alignment: .leading, spacing: PlyneSpacing.s3) {
            HStack {
                Text(dayTitle)
                    .font(.plyneSection)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                HStack(spacing: PlyneSpacing.s1) {
                    DashNavButton(systemImage: "chevron.left", accessibilityKey: "dashboard.day.previous") {
                        model.stepDay(by: -1)
                    }
                    DashNavButton(systemImage: "chevron.right", accessibilityKey: "dashboard.day.next",
                                  disabled: !model.canStepForward) {
                        model.stepDay(by: 1)
                    }
                }
            }
            DayTimelineView(items: model.timeline)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .animation(reduceMotion ? nil : PlyneMotion.ease(), value: model.day)
        }
    }

    private func sectionHeader(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.plyneSection)
            .accessibilityAddTraits(.isHeader)
    }

    /// "Today" when the timeline shows today; otherwise the localized date.
    private var dayTitle: String {
        if Calendar.current.isDateInToday(model.day) {
            return String(localized: "dashboard.section.today")
        }
        return model.day.formatted(.dateTime.weekday(.wide).month().day())
    }
}

/// A small frosted day-navigation chevron, styled on the popover's control
/// surface (so the dashboard and popover share one button language) rather than
/// the stock bordered button. Recedes to 40% when disabled — the design's
/// treatment for "can't go into the future".
private struct DashNavButton: View {
    let systemImage: String
    let accessibilityKey: LocalizedStringKey
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 24)
                .contentShape(Rectangle())
                .plyneControlSurface(RoundedRectangle(cornerRadius: 6, style: .continuous), strokeOpacity: 0.10)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
        .accessibilityLabel(Text(accessibilityKey))
    }
}
