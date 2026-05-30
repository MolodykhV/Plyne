import PlyneAnalytics
import SwiftUI

/// A calm 7×24 (weekday × hour) focus heatmap. One accent colour at varying
/// intensity — no numbers, no "best day", no good/bad hues. Under Increase
/// Contrast or Reduce Transparency it switches from an opacity ramp to a
/// discrete bordered scale so low-intensity cells stay visible.
struct WeekHeatmapView: View {
    let heatmap: WeekHeatmap

    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private let cellSize: CGFloat = 12
    private let spacing: CGFloat = 2
    private let labelWidth: CGFloat = 30

    private var highContrast: Bool { contrast == .increased || reduceTransparency }

    var body: some View {
        Grid(horizontalSpacing: spacing, verticalSpacing: spacing) {
            ForEach(0..<7, id: \.self) { day in
                GridRow {
                    Text(weekdayLabel(day))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: labelWidth, alignment: .trailing)
                    ForEach(0..<24, id: \.self) { hour in
                        cell(day: day, hour: hour)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(rowSummary(day))
            }
        }
        // The grid is an accessibility container (its rows are elements), so it
        // must be `.contain` for the label to be announced before the rows.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("heatmap.title"))
    }

    @ViewBuilder
    private func cell(day: Int, hour: Int) -> some View {
        let intensity = heatmap.normalizedIntensity(day: day, hour: hour)
        let hasFocus = heatmap.minutes(day: day, hour: hour) > 0
        RoundedRectangle(cornerRadius: 2)
            .fill(fillColor(intensity: intensity, hasFocus: hasFocus))
            .overlay {
                if highContrast {
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(Color.primary.opacity(0.25), lineWidth: 0.5)
                }
            }
            .frame(width: cellSize, height: cellSize)
    }

    private func fillColor(intensity: Double, hasFocus: Bool) -> Color {
        guard hasFocus else { return Color.secondary.opacity(highContrast ? 0.12 : 0.08) }
        if highContrast {
            // Discrete 3-step solid scale (no translucency to fight contrast).
            switch intensity {
            case ..<0.34: return Color.accentColor.opacity(0.45)
            case ..<0.67: return Color.accentColor.opacity(0.7)
            default: return Color.accentColor
            }
        }
        let floor = 0.18
        return Color.accentColor.opacity(floor + (1 - floor) * intensity)
    }

    // MARK: - Labels & accessibility

    private func dayDate(_ day: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: day, to: heatmap.weekStart) ?? heatmap.weekStart
    }

    private func weekdayLabel(_ day: Int) -> String {
        dayDate(day).formatted(.dateTime.weekday(.abbreviated))
    }

    /// "Tuesday: focus at 9, 10 and 14." or "Tuesday: no focus recorded."
    private func rowSummary(_ day: Int) -> String {
        let weekday = dayDate(day).formatted(.dateTime.weekday(.wide))
        let activeHours = (0..<24).filter { heatmap.minutes(day: day, hour: $0) > 0 }
        guard !activeHours.isEmpty else {
            return String(localized: "heatmap.row.empty \(weekday)")
        }
        let base = Calendar.current.startOfDay(for: dayDate(day))
        let hourStrings = activeHours.map { hour -> String in
            let date = Calendar.current.date(byAdding: .hour, value: hour, to: base) ?? base
            return date.formatted(.dateTime.hour())
        }
        let list = hourStrings.formatted(.list(type: .and))
        return String(localized: "heatmap.row.summary \(weekday) \(list)")
    }
}
