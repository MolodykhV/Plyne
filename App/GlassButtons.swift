import SwiftUI

// Liquid Glass is confined to the action/control layer (per the concept's
// "glass on the control layer only" rule). The primary action is a filled
// accent capsule (the design's hero); the secondary is frosted glass. Both
// degrade for Reduce Transparency / Increase Contrast — translucency and the
// accent glow are dropped when the user has opted out.

/// The design's lively-but-calm primary: a filled slate-accent capsule with a
/// soft top-gloss, a hairline highlight, and a quiet accent glow — clearly the
/// one hero action per pane. Stays a solid fill (so it reads under Reduce
/// Transparency); the glow is removed there and a firm border is added under
/// Increase Contrast. No drifting sheen (that would be decorative motion).
struct PlyneAccentButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let increased = contrast == .increased
        let shape = RoundedRectangle(cornerRadius: PlyneRadius.sm, style: .continuous)
        // The dark accent is light, so near-black ink reads better on it than
        // white; light mode keeps white ink (matches the design's on-accent).
        let ink: Color = scheme == .dark ? Color(red: 0.05, green: 0.07, blue: 0.09) : .white

        return configuration.label
            .font(.callout.weight(.semibold))
            .foregroundStyle(ink)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background {
                shape.fill(Color.accentColor)
                    .overlay(
                        LinearGradient(
                            colors: [.white.opacity(0.22), .white.opacity(0.02), .black.opacity(0.10)],
                            startPoint: .top, endPoint: .bottom
                        )
                        .clipShape(shape)
                    )
                    .overlay(shape.strokeBorder(.white.opacity(0.28), lineWidth: 0.5))
                    .brightness(pressed ? -0.05 : 0)
            }
            .overlay {
                if increased { shape.strokeBorder(Color.primary.opacity(0.55), lineWidth: 1) }
            }
            .shadow(color: Color.accentColor.opacity(reduceTransparency ? 0 : 0.40),
                    radius: pressed ? 4 : 9, y: pressed ? 2 : 4)
            .scaleEffect(reduceMotion ? 1 : (pressed ? 0.985 : 1))
            .animation(reduceMotion ? nil : PlyneMotion.ease(PlyneMotion.fast), value: pressed)
            .contentShape(shape)
    }
}

/// A prominent primary action.
struct PrimaryButton: View {
    let titleKey: LocalizedStringKey
    let action: () -> Void

    init(_ titleKey: LocalizedStringKey, action: @escaping () -> Void) {
        self.titleKey = titleKey
        self.action = action
    }

    var body: some View {
        Button(titleKey, action: action)
            .buttonStyle(PlyneAccentButtonStyle())
    }
}

/// The secondary action: a frosted (control-layer glass) capsule that shares
/// the primary's exact geometry — same height, radius, and weight — so the two
/// sit flush side-by-side in the running / ended / overflow / retro panes.
/// Solid neutral fill under Reduce Transparency, firmer border under Increase
/// Contrast.
struct PlyneSecondaryButtonStyle: ButtonStyle {
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let increased = contrast == .increased
        let shape = RoundedRectangle(cornerRadius: PlyneRadius.sm, style: .continuous)

        return configuration.label
            .font(.callout.weight(.semibold))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background {
                if reduceTransparency || increased {
                    shape.fill(Color.primary.opacity(increased ? 0.12 : 0.08))
                } else {
                    shape.fill(.thinMaterial)
                }
            }
            .overlay(shape.strokeBorder(Color.primary.opacity(increased ? 0.30 : 0.14), lineWidth: 1))
            // A faint scrim on press (brightness wouldn't show on a material).
            .overlay(shape.fill(Color.primary.opacity(pressed ? 0.06 : 0)))
            .scaleEffect(reduceMotion ? 1 : (pressed ? 0.985 : 1))
            .animation(reduceMotion ? nil : PlyneMotion.ease(PlyneMotion.fast), value: pressed)
            .contentShape(shape)
    }
}

/// A secondary action; frosted glass on the control layer.
struct SecondaryButton: View {
    let titleKey: LocalizedStringKey
    let action: () -> Void

    init(_ titleKey: LocalizedStringKey, action: @escaping () -> Void) {
        self.titleKey = titleKey
        self.action = action
    }

    var body: some View {
        Button(titleKey, action: action)
            .buttonStyle(PlyneSecondaryButtonStyle())
    }
}
