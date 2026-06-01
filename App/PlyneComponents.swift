import Foundation
import SwiftUI

// Shared, reusable UI built on the Plyne design tokens. These pieces give the
// surfaces their warmth and hierarchy: the accent intention pill, the big time
// readout, suggestion chips (with a flow layout), styled text fields, key caps,
// and the faint brand-wave flourish. The brand sweep gauge lives in its own
// file (`PlyneGauge.swift`).

// MARK: - Time readout

/// The calm hero of the running/overflow panes: a large SF-Rounded, tabular
/// readout with a quiet uppercase sublabel ("remaining" / "in focus" / "past
/// the bell") that tells a sighted user, at a glance, whether the number counts
/// down or up. Accent-tinted in overflow to mark the phase without celebration.
struct TimeReadout: View {
    let text: String
    let accessibility: LocalizedStringResource
    var sub: LocalizedStringKey?
    var accent: Bool = false

    var body: some View {
        VStack(spacing: PlyneSpacing.s2 - 2) {
            Text(text)
                .font(.plyneReadout)
                .foregroundStyle(accent ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.primary))
            if let sub {
                Text(sub)
                    .font(.caption.weight(.medium))
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        // One element: the spoken label already conveys remaining/elapsed, so
        // the visible sublabel must not be read a second time.
        .accessibilityElement()
        .accessibilityLabel(Text(accessibility))
    }
}

// MARK: - Intention pill

/// The current focus shown as a quiet accent capsule (a small dot + the text).
/// Centred in its pane; renders nothing when there is no intention. The accent
/// wash strengthens under Increase Contrast so the capsule stays defined.
struct IntentionPill: View {
    let intention: String?
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        if let intention, !intention.isEmpty {
            let increased = contrast == .increased
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                HStack(spacing: 7) {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 5, height: 5)
                    Text(intention)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .font(.callout.weight(.medium))
                .padding(.vertical, 5)
                .padding(.leading, 9)
                .padding(.trailing, 11)
                .background(Capsule().fill(Color.accentColor.opacity(increased ? 0.18 : 0.12)))
                .overlay(Capsule().strokeBorder(Color.accentColor.opacity(increased ? 0.6 : 0.32), lineWidth: 1))
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Suggestion chips

/// Recent intentions as tappable capsule chips that wrap onto multiple lines.
/// Selecting one fills the field (the caller decides what happens next).
struct IntentionChips: View {
    let titles: [String]
    let onSelect: (Int) -> Void

    var body: some View {
        FlowLayout(spacing: PlyneSpacing.s2, lineSpacing: PlyneSpacing.s2) {
            ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                Button { onSelect(index) } label: {
                    Text(title)
                        .font(.footnote)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 11)
                        .plyneControlSurface(Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
    }
}

/// A minimal wrapping layout: lays children left-to-right, wrapping to a new
/// line when the row is full. Used for the suggestion chips so a long recent
/// phrase (or RU text) wraps instead of truncating the row.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.replacingUnspecifiedDimensions().width
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

// MARK: - Control surface (the "frost" material, with accessible fallbacks)

/// A translucent control-layer surface (the design's "frost"): `.thinMaterial`
/// with a hairline border at the given shape. It degrades to a solid neutral
/// fill under Reduce Transparency and a stronger border under Increase Contrast,
/// so every chip / tile / key cap shares one accessible material treatment
/// rather than each re-deriving the fallback. Glass stays on the control layer
/// only — content tiles use `plyneTile` instead.
private struct PlyneControlSurface<S: InsettableShape>: ViewModifier {
    let shape: S
    var solidFill: Double
    var strokeOpacity: Double

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let increased = contrast == .increased
        let opaque = reduceTransparency || increased
        return content
            .background {
                if opaque {
                    shape.fill(Color.primary.opacity(increased ? solidFill + 0.03 : solidFill))
                } else {
                    shape.fill(.thinMaterial)
                }
            }
            .overlay {
                shape.strokeBorder(Color.primary.opacity(increased ? 0.28 : strokeOpacity), lineWidth: 1)
            }
    }
}

extension View {
    /// Frosted control surface with a Reduce-Transparency / Increase-Contrast
    /// fallback. Pass the shape (e.g. `Capsule()` or a continuous
    /// `RoundedRectangle`) so the fill and border share it.
    func plyneControlSurface<S: InsettableShape>(
        _ shape: S,
        solidFill: Double = 0.06,
        strokeOpacity: Double = 0.12
    ) -> some View {
        modifier(PlyneControlSurface(shape: shape, solidFill: solidFill, strokeOpacity: strokeOpacity))
    }
}

// MARK: - Text field styling

/// A frosted, rounded text-field surface with an accent focus ring. The control
/// layer is allowed translucency, with a solid fallback under Reduce
/// Transparency; `focused` is passed in from the caller's `@FocusState` so the
/// ring reflects real focus.
struct PlyneFieldModifier: ViewModifier {
    var focused: Bool
    var big: Bool = false

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .font(big ? .system(size: 16) : .body)
            .padding(.horizontal, big ? 14 : 12)
            .padding(.vertical, big ? 11 : 9)
            .background(
                RoundedRectangle(cornerRadius: PlyneRadius.sm, style: .continuous)
                    .fill(reduceTransparency ? AnyShapeStyle(Color.primary.opacity(0.06)) : AnyShapeStyle(.thinMaterial))
            )
            .overlay(
                RoundedRectangle(cornerRadius: PlyneRadius.sm, style: .continuous)
                    .strokeBorder(focused ? Color.accentColor : Color.primary.opacity(0.12),
                                  lineWidth: focused ? 1.5 : 1)
            )
    }
}

extension View {
    func plyneField(focused: Bool, big: Bool = false) -> some View {
        modifier(PlyneFieldModifier(focused: focused, big: big))
    }
}

// MARK: - Symbol tile & key cap

/// A quiet rounded tile holding a neutral SF Symbol — the onboarding hero and
/// other "icon chip" spots.
struct PlyneSymbolTile: View {
    let symbol: String
    var size: CGFloat = 52
    var iconSize: CGFloat = 26

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: iconSize, weight: .regular))
            .foregroundStyle(.secondary)
            .frame(width: size, height: size)
            // Decorative content, not a control — a neutral tile, not glass.
            .plyneTile(cornerRadius: PlyneRadius.md, fill: 0.05)
            .accessibilityHidden(true)
    }
}

/// A single keyboard key rendered as a small cap (for the onboarding shortcuts).
struct PlyneKeyCap: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
            .frame(minWidth: 22)
            .frame(height: 24)
            .padding(.horizontal, 6)
            .plyneControlSurface(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

// MARK: - Flow-weave crown

/// The Plyne flow-weave artwork (the brand's crossing ribbons) used as a faint,
/// decorative crown across the top of a surface — the popover and the frosted
/// windows — exactly as in the approved design. It is the real two-tone brand
/// mark (its hue is brand identity, like the app icon, not a UI accent), kept
/// faint and masked so it fades into the content, and removed entirely under
/// Reduce Transparency so the content stays maximally legible.
private struct PlyneCrownModifier: ViewModifier {
    var height: CGFloat
    var opacity: Double
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content.background(alignment: .top) {
            if !reduceTransparency {
                Image("FlowArt")
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
                    .clipped()
                    .opacity(opacity)
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .black, location: 0),
                                .init(color: .black, location: 0.45),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }
}

extension View {
    /// Adds the faint flow-weave crown behind this surface.
    func plyneCrown(height: CGFloat = 130, opacity: Double = 0.45) -> some View {
        modifier(PlyneCrownModifier(height: height, opacity: opacity))
    }
}
