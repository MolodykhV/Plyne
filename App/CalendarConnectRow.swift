import AppKit
import PlyneCalendar
import SwiftUI

/// The idle-screen calendar affordance. Shown only while access isn't granted:
/// an explicit opt-in when undecided, a calm reconnect line when denied, and a
/// plain unavailable note when restricted. Nothing once authorized — no
/// "connected!" celebration (concept: no drama).
struct CalendarConnectRow: View {
    @Environment(PlyneStore.self) private var store

    var body: some View {
        switch store.calendarAuthorization {
        case .notDetermined:
            VStack(alignment: .leading, spacing: 2) {
                Button("calendar.connect") { store.connectCalendar() }
                    .buttonStyle(.plain)
                    .font(.footnote)
                    .accessibilityHint(Text("calendar.connect.rationale"))
                Text("calendar.connect.rationale")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    // The same text is the button's accessibilityHint, so hide
                    // this visible caption from VoiceOver to avoid reading it twice.
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case .denied:
            VStack(alignment: .leading, spacing: 2) {
                Text("calendar.denied")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("calendar.denied.open_settings") { Self.openCalendarSettings() }
                    .buttonStyle(.plain)
                    .font(.caption)
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
