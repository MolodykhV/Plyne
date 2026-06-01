import SwiftUI

/// The popover's tertiary action — a quiet inline text button (the design's
/// `TextBtn`): an optional leading SF Symbol and a label, no fill. Used for the
/// footer affordances ("Add a past session", "Overview"), "Quit Plyne",
/// "Start without naming a focus", and — in its `strong` (accent) form —
/// "Open Settings". It brightens on hover (the design's only feedback), so it
/// reads as a control rather than a stray gray label.
struct PlyneTextButton: View {
    let titleKey: LocalizedStringKey
    var systemImage: String?
    var strong: Bool
    let action: () -> Void

    @State private var hovering = false

    init(
        _ titleKey: LocalizedStringKey,
        systemImage: String? = nil,
        strong: Bool = false,
        action: @escaping () -> Void
    ) {
        self.titleKey = titleKey
        self.systemImage = systemImage
        self.strong = strong
        self.action = action
    }

    private var tint: Color {
        if strong { return .accentColor }
        return hovering ? .primary : .secondary
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.footnote.weight(.medium))
                }
                Text(titleKey)
                    .font(.footnote.weight(strong ? .semibold : .medium))
            }
            .foregroundStyle(tint)
            .opacity(strong && hovering ? 0.8 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
