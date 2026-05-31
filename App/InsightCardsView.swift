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
        VStack(alignment: .leading, spacing: 8) {
            Text("dashboard.section.observations")
                .font(.title3)
                .accessibilityAddTraits(.isHeader)
            FocusWindowCard(insight: focusWindow)
        }
    }
}

/// One observation: the recurring band where focus tends to land. Rendered as a
/// quiet content tile — no accent fill, no celebration — matching the heatmap's
/// neutral surface. Materials/glass stay on control layers, not content.
private struct FocusWindowCard: View {
    let insight: FocusWindowInsight

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "clock")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 18)
                .accessibilityHidden(true)
            Text(message)
                .font(.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.08)))
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
