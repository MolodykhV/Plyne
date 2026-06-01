import PlyneAnalytics
import SwiftUI

/// The dashboard's "Observations" section: calm, descriptive cards drawn from
/// the last two weeks. Observer register only — each card names *what the data
/// shows*, never prescribes (concept "Тональность аналитики"). When nothing
/// qualifies, ``DashboardView`` omits the whole section: Plyne leaves the space
/// empty rather than filling it with a "you did nothing" message.
struct InsightCardsView: View {
    let focusWindow: FocusWindowInsight

    var body: some View {
        VStack(alignment: .leading, spacing: PlyneSpacing.s3) {
            Text("dashboard.section.observations")
                .font(.plyneSection)
                .accessibilityAddTraits(.isHeader)
            FocusWindowCard(insight: focusWindow)
        }
    }
}

/// One observation: the recurring band where focus tends to land. A quiet note
/// — a neutral icon chip and a plain sentence on a soft content tile, no accent
/// celebration. Materials/glass stay on control layers, not content.
private struct FocusWindowCard: View {
    let insight: FocusWindowInsight

    var body: some View {
        HStack(alignment: .center, spacing: PlyneSpacing.s3) {
            Image(systemName: "clock")
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 34)
                .plyneControlSurface(RoundedRectangle(cornerRadius: 9, style: .continuous), strokeOpacity: 0.08)
                .accessibilityHidden(true)
            Text(message)
                .font(.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(PlyneSpacing.s3)
        .plyneTile()
        .accessibilityElement(children: .combine)
    }

    private var message: String {
        String(localized: "insight.focusWindow \(hourLabel(insight.startHour)) \(hourLabel(insight.endHour))")
    }

    /// A localized label for an hour-of-day band boundary. Midnight (0, or 24 at
    /// the end of a late band) reads as the word "midnight" rather than the
    /// formatter's "12 AM" / "0", which would make a band ending at the day
    /// boundary read as a count-down glitch ("…10 PM to 12 AM"). Other hours use
    /// the locale's clock format (12h or 24h), matching the heatmap labels.
    private func hourLabel(_ hour: Int) -> String {
        guard hour != 0, hour != 24 else { return String(localized: "insight.time.midnight") }
        let calendar = Calendar.current
        let base = calendar.startOfDay(for: Date())
        let date = calendar.date(byAdding: .hour, value: hour, to: base) ?? base
        return date.formatted(.dateTime.hour())
    }
}
