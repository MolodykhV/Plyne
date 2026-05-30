import PlyneAnalytics
import SwiftUI

/// The dashboard window: this week's focus heatmap on top, the selected day's
/// timeline below. Two stacked sections (no tabs — they'd hide context). Reads
/// its data from ``DashboardModel``.
struct DashboardView: View {
    @Environment(DashboardModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            weekSection
            Divider()
            daySection
        }
        .padding(16)
        .frame(minWidth: 420, minHeight: 520)
        // Data load is triggered by DashboardWindowController.show() on every
        // open (the window is reused, so onAppear wouldn't fire on reopen).
    }

    private var weekSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("dashboard.section.week")
                .font(.title3)
                .accessibilityAddTraits(.isHeader)
            if let heatmap = model.weekHeatmap {
                WeekHeatmapView(heatmap: heatmap)
            }
        }
    }

    private var daySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(dayTitle)
                    .font(.title3)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button {
                    model.stepDay(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("dashboard.day.previous"))

                Button {
                    model.stepDay(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
                .disabled(!model.canStepForward)
                .accessibilityLabel(Text("dashboard.day.next"))
            }
            DayTimelineView(items: model.timeline)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.day)
        }
    }

    /// "Today" when the timeline shows today; otherwise the localized date.
    private var dayTitle: String {
        if Calendar.current.isDateInToday(model.day) {
            return String(localized: "dashboard.section.today")
        }
        return model.day.formatted(.dateTime.weekday(.wide).month().day())
    }
}
