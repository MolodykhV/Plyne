import SwiftUI
import PlyneTimer

/// The status-item glyph: a small ring whose geometry — not colour — encodes
/// the timer phase, so it reads correctly as a template image that the menu
/// bar tints for light/dark/vibrancy.
///
/// A live `Canvas`/`Shape` is not reliable inside a `MenuBarExtra` label
/// (AppKit rasterizes the label region), so this view is rendered to a
/// template `NSImage` by ``RingImageCache`` and presented via `Image(nsImage:)`.
struct RingIcon: View {
    let progress: TimerProgress
    let increasedContrast: Bool

    private var stroke: CGFloat { increasedContrast ? 2.4 : 1.7 }

    var body: some View {
        ZStack {
            // Track: always present, faint. In idle it is the whole icon.
            Circle()
                .stroke(.primary.opacity(increasedContrast ? 0.5 : 0.3), lineWidth: stroke)

            switch progress.phase {
            case .idle:
                EmptyView()

            case .running:
                arc(to: progress.fraction)

            case .flowmodoro:
                // Open-ended: a steady centre dot signals "in session" without
                // implying a finish line.
                Circle()
                    .fill(.primary)
                    .frame(width: stroke * 2.2, height: stroke * 2.2)

            case .mainEnded, .finished:
                arc(to: 1)

            case .overflow:
                arc(to: 1)
                // A distinct inner mark: continuing past the bell, calmly — not
                // a flourish.
                Circle()
                    .trim(from: 0, to: 0.5)
                    .stroke(.primary, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(stroke * 2.4)
            }
        }
        .padding(stroke)
    }

    private func arc(to fraction: Double) -> some View {
        Circle()
            .trim(from: 0, to: max(fraction, 0.0001))
            .stroke(.primary, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
            .rotationEffect(.degrees(-90))
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
