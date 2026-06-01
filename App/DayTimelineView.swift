import PlyneAnalytics
import PlyneCore
import SwiftUI

/// A vertical, time-ordered list of the day's focus sessions and calendar
/// blocks, connected by a quiet timeline rail. Factual, never scored: an
/// interrupted session looks identical to a completed one, and calendar rows
/// read lighter (a neutral symbol) so the user's own sessions — marked with the
/// Plyne gauge in the accent — stay primary.
struct DayTimelineView: View {
    let items: [DayTimelineItem]

    // No inner ScrollView: the dashboard scrolls as one continuous column
    // (heatmap → observations → timeline), matching the approved design.
    var body: some View {
        if items.isEmpty {
            Text("timeline.empty")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 80)
                .multilineTextAlignment(.center)
        } else {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    TimelineRow(item: item, isLast: index == items.count - 1)
                }
            }
            .padding(.vertical, PlyneSpacing.s1)
        }
    }
}

private struct TimelineRow: View {
    let item: DayTimelineItem
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: PlyneSpacing.s3) {
            Text(item.start.formatted(.dateTime.hour().minute()))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .trailing)
                .padding(.top, 4)

            // The rail: an icon chip with a connector running to the next row.
            VStack(spacing: 3) {
                iconChip
                if !isLast {
                    Rectangle()
                        .fill(Color.primary.opacity(0.12))
                        .frame(width: 1.5)
                        .frame(maxHeight: .infinity)
                }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.callout)
                    .foregroundStyle(isCalendar ? .secondary : .primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 5)
            .padding(.bottom, isLast ? 0 : PlyneSpacing.s4)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    /// The 26-pt rail node: the accent gauge for the user's own sessions, a
    /// neutral SF Symbol for calendar blocks.
    private var iconChip: some View {
        ZStack {
            if isCalendar {
                Image(systemName: symbol)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                PlyneGauge(phase: .idle, tint: .accentColor, lineWidth: 2.6)
                    .frame(width: 16, height: 16)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: 26, height: 26)
        .plyneControlSurface(RoundedRectangle(cornerRadius: 8, style: .continuous), strokeOpacity: 0.08)
        // VoiceOver can't see the symbol/weight cue, so name the kind (the row
        // combines children into one spoken string).
        .accessibilityLabel(Text(isCalendar ? "timeline.kind.calendar" : "timeline.kind.session"))
    }

    private var isCalendar: Bool {
        if case .calendarBlock = item.kind { return true }
        return false
    }

    private var symbol: String {
        switch item.kind {
        case .session:
            return "timer"
        case let .calendarBlock(block):
            switch block.kind {
            case .meeting: return "person.2"
            case .lunch: return "fork.knife"
            case .focus: return "scope"
            case .other: return "calendar"
            }
        }
    }

    private var title: String {
        switch item.kind {
        case let .session(session):
            return session.intention?.trimmedNonEmpty ?? String(localized: "timeline.session.untitled")
        case let .calendarBlock(block):
            return block.title
        }
    }

    private var subtitle: String {
        if item.isRunning {
            return String(localized: "timeline.session.inProgress")
        }
        guard let end = item.end else { return "" }
        let minutes = Int((end.timeIntervalSince(item.start) / 60).rounded())
        return Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }
}
