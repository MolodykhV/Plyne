import AppKit
import PlyneCalendar
import SwiftUI

/// The idle-screen calendar affordance. Shown only while access isn't granted:
/// an explicit opt-in card when undecided, a calm reconnect line when denied,
/// and a plain unavailable note when restricted. Nothing once authorized — no
/// "connected!" celebration (concept: no drama).
struct CalendarConnectRow: View {
    @Environment(PlyneStore.self) private var store
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    private var increased: Bool { contrast == .increased }
    private var cardShape: RoundedRectangle { RoundedRectangle(cornerRadius: PlyneRadius.sm, style: .continuous) }

    var body: some View {
        switch store.calendarAuthorization {
        case .notDetermined:
            // A tidy, neutral frosted card with a dashed "add" border — the
            // accent is carried only by the calendar glyph, so the row stays
            // calm rather than a blue box (matches the approved design).
            Button { store.connectCalendar() } label: {
                HStack(spacing: PlyneSpacing.s3) {
                    Image(systemName: "calendar")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("calendar.connect")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("calendar.connect.rationale")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: PlyneSpacing.s2)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    cardShape.fill(reduceTransparency ? AnyShapeStyle(Color.primary.opacity(0.05)) : AnyShapeStyle(.thinMaterial))
                )
                .overlay(
                    cardShape.strokeBorder(
                        Color.primary.opacity(increased ? 0.32 : 0.16),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                    )
                )
                .contentShape(cardShape)
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("calendar.connect.rationale"))

        case .denied:
            HStack(spacing: PlyneSpacing.s2) {
                Image(systemName: "calendar")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text("calendar.denied")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: PlyneSpacing.s2)
                PlyneTextButton("calendar.denied.open_settings", systemImage: "gearshape", strong: true) {
                    Self.openCalendarSettings()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case .restricted:
            Text("calendar.restricted")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .authorized:
            EmptyView()
        }
    }

    /// Opens the Calendars pane in System Settings (Privacy & Security).
    private static func openCalendarSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") else { return }
        NSWorkspace.shared.open(url)
    }
}
