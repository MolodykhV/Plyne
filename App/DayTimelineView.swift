import PlyneAnalytics
import PlyneCore
import SwiftUI

/// A vertical, time-ordered list of the day's focus sessions and calendar
/// blocks. Factual, never scored: an interrupted session looks identical to a
/// completed one, and calendar rows read lighter so the user's own sessions
/// stay primary.
struct DayTimelineView: View {
    let items: [DayTimelineItem]

    var body: some View {
        if items.isEmpty {
            Text("timeline.empty")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .multilineTextAlignment(.center)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(items) { item in
                        TimelineRow(item: item)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

private struct TimelineRow: View {
    let item: DayTimelineItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(item.start.formatted(.dateTime.hour().minute()))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .trailing)

            Image(systemName: symbol)
                .font(.callout)
                .foregroundStyle(isCalendar ? .secondary : .primary)
                .frame(width: 18)
                // VoiceOver can't see the symbol/weight cue, so name the kind
                // (the row combines children into one spoken string).
                .accessibilityLabel(Text(isCalendar ? "timeline.kind.calendar" : "timeline.kind.session"))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.callout)
                    .foregroundStyle(isCalendar ? .secondary : .primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
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
