import SwiftUI

@main
struct PlyneApp: App {
    var body: some Scene {
        MenuBarExtra {
            MenuBarContent()
        } label: {
            // Temporary glyph. The bespoke single-stroke wave lands in Step 1.5
            // alongside the real menu-bar surface.
            Image(systemName: "circle.dotted")
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Plyne")
                .font(.headline)
            Text("menubar.tagline")
                .font(.callout)
                .foregroundStyle(.secondary)

            Divider()

            Text("menubar.step1.placeholder")
                .font(.callout)
                .foregroundStyle(.secondary)

            Divider()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text("menubar.quit")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .keyboardShortcut("q")
        }
        .padding(16)
        .frame(width: 260)
    }
}
