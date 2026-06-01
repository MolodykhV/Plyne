import PlyneAnalytics
import SwiftUI

/// A calm 7×24 (weekday × hour) focus heatmap. One accent colour at varying
/// intensity — no numbers, no "best day", no good/bad hues. Cells are softly
/// rounded with a faint accent rim so a light week still reads as inviting
/// rather than clinical. Under Increase Contrast or Reduce Transparency it
/// switches from an opacity ramp to a discrete bordered scale so low-intensity
/// cells stay visible.
struct WeekHeatmapView: View {
    let heatmap: WeekHeatmap

    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private let cellSize: CGFloat = 13
    private let spacing: CGFloat = 3
    private let labelWidth: CGFloat = 30
    private let cornerRadius: CGFloat = 3.5

    private var highContrast: Bool { contrast == .increased || reduceTransparency }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
            hourAxis
        }
        // The grid is an accessibility container (its rows are elements), so it
        // must be `.contain` for the label to be announced before the rows.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("heatmap.title"))
    }

    /// A sparse hour axis under the grid (12a · 6a · 12p · 6p · 11p, localized),
    /// aligned to each cell column's centre. Hidden from VoiceOver — the per-row
    /// summaries already speak the active hours. The label track starts after the
    /// weekday gutter and uses the real column pitch (cell + spacing), so a tick
    /// sits exactly under its cell rather than on an averaged grid.
    private var hourAxis: some View {
        let pitch = cellSize + spacing
        return HStack(spacing: spacing) {
            Color.clear.frame(width: labelWidth, height: 1)
            ZStack(alignment: .topLeading) {
                ForEach([0, 6, 12, 18, 23], id: \.self) { hour in
                    Text(axisLabel(hour))
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                        .fixedSize()
                        .alignmentGuide(.leading) { $0.width / 2 }
                        .offset(x: CGFloat(hour) * pitch + cellSize / 2, y: 0)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 12, alignment: .topLeading)
        }
        .padding(.top, 5)
        .accessibilityHidden(true)
    }

    private func axisLabel(_ hour: Int) -> String {
        let base = Calendar.current.startOfDay(for: heatmap.weekStart)
        let date = Calendar.current.date(byAdding: .hour, value: hour, to: base) ?? base
        return date.formatted(.dateTime.hour())
    }

    @ViewBuilder
    private func cell(day: Int, hour: Int) -> some View {
        let intensity = heatmap.normalizedIntensity(day: day, hour: hour)
        let hasFocus = heatmap.minutes(day: day, hour: hour) > 0
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(fillColor(intensity: intensity, hasFocus: hasFocus))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(borderColor(intensity: intensity, hasFocus: hasFocus), lineWidth: 0.5)
            }
            .frame(width: cellSize, height: cellSize)
    }

    private func fillColor(intensity: Double, hasFocus: Bool) -> Color {
        guard hasFocus else { return Color.primary.opacity(highContrast ? 0.10 : 0.05) }
        if highContrast {
            // Discrete 3-step solid scale (no translucency to fight contrast).
            switch intensity {
            case ..<0.34: return Color.accentColor.opacity(0.45)
            case ..<0.67: return Color.accentColor.opacity(0.7)
            default: return Color.accentColor
            }
        }
        // A warm floor so even a quiet hour reads as "some focus", not blank.
        let floor = 0.14
        return Color.accentColor.opacity(floor + (1 - floor) * intensity)
    }

    private func borderColor(intensity: Double, hasFocus: Bool) -> Color {
        if highContrast {
            return hasFocus ? Color.primary.opacity(0.25) : Color.primary.opacity(0.18)
        }
        return hasFocus ? Color.accentColor.opacity(0.25) : Color.primary.opacity(0.06)
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
