import SwiftUI
import PlyneTimer

/// The status-item glyph: the abstract Plyne "sweep" gauge whose *shape* — not
/// colour — encodes the timer phase, so it reads correctly as a template image
/// that the menu bar tints for light/dark/vibrancy. It is deliberately not a
/// clock (no ticks, no hands; it opens at the bottom).
///
/// A live `Canvas` is not reliable inside a `MenuBarExtra` label (AppKit
/// rasterizes the label region), so this view is rendered to a template
/// `NSImage` by ``RingImageCache`` and presented via `Image(nsImage:)`.
struct RingIcon: View {
    let progress: TimerProgress
    let increasedContrast: Bool

    var body: some View {
        PlyneGauge(
            phase: gaugePhase,
            fraction: progress.fraction,
            tint: .primary,
            lineWidth: increasedContrast ? 2.9 : 2.4,
            // The menu bar needs a near-opaque track/node so every state reads
            // at ~18 pt once the system tints the template image.
            bold: true
        )
    }

    private var gaugePhase: PlyneGauge.Phase {
        switch progress.phase {
        case .idle: return .idle
        case .running: return .running
        case .flowmodoro: return .flowmodoro
        case .overflow: return .overflow
        case .mainEnded, .finished: return .ended
        }
    }
}

/// Renders ``RingIcon`` to a template `NSImage`, memoized so the (relatively
/// expensive) `ImageRenderer` runs only when the visible result changes —
/// i.e. when the integer percent, phase, or contrast flips, not every tick.
@MainActor
final class RingImageCache {
    private struct Key: Equatable {
        let phase: TimerProgress.Phase
        let percent: Int
        let increasedContrast: Bool
    }

    private static let pointSize: CGFloat = 18

    private var key: Key?
    private var cached = NSImage(size: NSSize(width: pointSize, height: pointSize))

    func image(for progress: TimerProgress, increasedContrast: Bool) -> NSImage {
        let next = Key(
            phase: progress.phase,
            percent: Int((progress.fraction * 100).rounded()),
            increasedContrast: increasedContrast
        )
        guard next != key else { return cached }

        let renderer = ImageRenderer(
            content: RingIcon(progress: progress, increasedContrast: increasedContrast)
                .frame(width: Self.pointSize, height: Self.pointSize)
        )
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        if let rendered = renderer.nsImage {
            rendered.isTemplate = true
            rendered.size = NSSize(width: Self.pointSize, height: Self.pointSize)
            cached = rendered
            key = next
        }
        return cached
    }
}

/// The `MenuBarExtra` label. Recomputes the template image from the current
/// progress and exposes a phase-appropriate VoiceOver label.
struct MenuBarLabel: View {
    let progress: TimerProgress
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var cache = RingImageCache()

    var body: some View {
        Image(nsImage: cache.image(for: progress, increasedContrast: contrast == .increased))
            .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: Text {
        switch progress.phase {
        case .idle:
            return Text("a11y.ring.idle")
        case .running:
            return Text("a11y.ring.running \(Int((progress.fraction * 100).rounded()))")
        case .flowmodoro:
            return Text("a11y.ring.flowmodoro")
        case .mainEnded, .finished:
            return Text("a11y.ring.ended")
        case .overflow:
            return Text("a11y.ring.overflow")
        }
    }
}
