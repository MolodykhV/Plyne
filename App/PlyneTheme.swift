import SwiftUI

// Plyne design tokens — the single source for spacing, corner radii, motion,
// and type used across every surface. Ported from the "calm northern" design
// system: a slate-blue accent (the AccentColor asset), warm-leaning neutrals,
// softer radii, and calm motion. Glass/material stays on the control layer
// only (see the concept doc); these tokens never put material behind content.

/// The 4-pt spacing scale. Use these instead of raw numbers so the vertical
/// rhythm stays consistent across panes and windows.
enum PlyneSpacing {
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 20
    static let s6: CGFloat = 24
    static let s7: CGFloat = 32
    static let s8: CGFloat = 44
}

/// Corner-radius scale — slightly softer than stock to read warmer.
enum PlyneRadius {
    static let xs: CGFloat = 7
    static let sm: CGFloat = 10
    static let md: CGFloat = 14
    static let lg: CGFloat = 18
    static let xl: CGFloat = 24
}

/// Calm motion: 160–250 ms, easeOut (the design's `cubic-bezier(0.22,1,0.36,1)`),
/// no bounce. Callers still gate these on Reduce Motion.
enum PlyneMotion {
    static let fast: Double = 0.16
    static let base: Double = 0.22
    static let slow: Double = 0.25

    /// The shared easeOut curve at a given duration.
    static func ease(_ duration: Double = base) -> Animation {
        .timingCurve(0.22, 1, 0.36, 1, duration: duration)
    }
}

extension AnyTransition {
    /// The transition between popover panes: the new pane rises in with a fade
    /// and a small scale-up; the old one fades and eases back slightly. Clearly
    /// noticeable but calm — no bounce, no parallax (per the concept). Scale and
    /// offset are render transforms, so they don't fight the popover's height
    /// change. Must be used with the swap wrapped in a container (a ZStack) that
    /// carries the `.animation`, so the two panes overlap and cross-dissolve.
    /// Callers gate it on Reduce Motion.
    static var plynePane: AnyTransition {
        .asymmetric(
            insertion: .opacity
                .combined(with: .scale(scale: 0.93, anchor: .center))
                .combined(with: .offset(y: 10)),
            removal: .opacity
                .combined(with: .scale(scale: 0.98, anchor: .center))
        )
    }
}

extension Font {
    /// The big timer readout: SF Rounded, semibold, tabular digits.
    static let plyneReadout = Font.system(size: 56, weight: .semibold, design: .rounded).monospacedDigit()

    /// Hero / window heading.
    static let plyneTitle = Font.system(size: 22, weight: .bold)

    /// A section heading inside a window (the design's 15 pt semibold).
    static let plyneSection = Font.system(size: 15, weight: .semibold)
}

/// A recessed content tile: a faint neutral fill and a hairline border. Used for
/// long-form content surfaces (observation card, notices, the meeting hint)
/// where material is *not* allowed — neutral, never accent. Both the fill and
/// the border strengthen under Increase Contrast so the tile keeps its edge for
/// low-vision users.
private struct PlyneTileModifier: ViewModifier {
    var cornerRadius: CGFloat
    var fill: Double
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let increased = contrast == .increased
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.primary.opacity(increased ? fill + 0.04 : fill))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(increased ? 0.22 : 0.08), lineWidth: 1)
            )
    }
}

extension View {
    func plyneTile(cornerRadius: CGFloat = PlyneRadius.md, fill: Double = 0.045) -> some View {
        modifier(PlyneTileModifier(cornerRadius: cornerRadius, fill: fill))
    }
}
