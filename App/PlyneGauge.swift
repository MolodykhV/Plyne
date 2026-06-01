import Foundation
import SwiftUI

// MARK: - Sweep gauge (the brand motif)

/// The Plyne mark: an abstract open gauge — *not* a clock (no ticks, no hands,
/// it opens at the bottom). State is read from shape, so the same drawing works
/// as an 18-pt monochrome menu-bar template and as a larger accent glyph in a
/// pane. Drawn in a fixed 24-unit space and scaled to the frame.
struct PlyneGauge: View {
    enum Phase { case idle, running, flowmodoro, overflow, ended }

    let phase: Phase
    var fraction: Double = 0
    /// The drawing colour (`.primary` for the template menu-bar image, the
    /// accent for in-pane glyphs).
    var tint: Color = .primary
    /// Stroke weight in 24-unit design space (the design's `sw`).
    var lineWidth: CGFloat = 2
    /// Menu-bar mode: a near-opaque track and node so the gauge stays legible at
    /// ~18 pt as a tinted template image (in-pane glyphs keep the faint track).
    var bold: Bool = false

    var body: some View {
        Canvas { ctx, size in
            let scale = size.width / 24
            let center = CGPoint(x: 12 * scale, y: 12 * scale)
            let radius = 8 * scale
            let stroke = lineWidth * scale
            let dotR = stroke * 0.92

            let gap = 92.0
            let start = 180 + gap / 2          // 226° — lower-left base
            let sweep = 360 - gap              // 268° of track
            let end = start + sweep            // lower-right base (clockwise)

            // A point on the gauge, measured clockwise from the top (0 = 12 o'clock).
            func point(_ deg: Double) -> CGPoint {
                let radians = deg * .pi / 180
                return CGPoint(x: center.x + radius * sin(radians), y: center.y - radius * cos(radians))
            }
            // A smooth arc approximated as a dense polyline (crisp at any render
            // scale, and free of the addArc clockwise/y-flip footgun).
            func arc(_ from: Double, _ toDeg: Double) -> Path {
                var path = Path()
                let steps = max(2, Int(abs(toDeg - from) / 3))
                for index in 0...steps {
                    let degree = from + (toDeg - from) * Double(index) / Double(steps)
                    let coord = point(degree)
                    if index == 0 { path.move(to: coord) } else { path.addLine(to: coord) }
                }
                return path
            }
            func line(_ path: Path, opacity: Double = 1, width: CGFloat? = nil) {
                ctx.stroke(
                    path,
                    with: .color(tint.opacity(opacity)),
                    style: StrokeStyle(lineWidth: width ?? stroke, lineCap: .round, lineJoin: .round)
                )
            }
            func dot(_ point: CGPoint, _ dotRadius: CGFloat, opacity: Double = 1) {
                let rect = CGRect(x: point.x - dotRadius, y: point.y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)
                ctx.fill(Path(ellipseIn: rect), with: .color(tint.opacity(opacity)))
            }

            let trackOpacity = bold ? (phase == .idle ? 0.95 : 0.8) : (phase == .idle ? 0.34 : 0.26)
            let idleNodeOpacity = bold ? 0.95 : 0.55

            // Track present in every state except the resolved "ended" (faint
            // in-pane, near-opaque in the menu bar).
            if phase != .ended {
                line(arc(start, end), opacity: trackOpacity)
            }

            switch phase {
            case .idle:
                // A hollow resting node at the start base.
                let base = point(start)
                let nodeRadius = dotR * 0.78
                let rect = CGRect(x: base.x - nodeRadius, y: base.y - nodeRadius, width: nodeRadius * 2, height: nodeRadius * 2)
                ctx.stroke(
                    Path(ellipseIn: rect),
                    with: .color(tint.opacity(idleNodeOpacity)),
                    style: StrokeStyle(lineWidth: stroke * 0.75)
                )

            case .running:
                // Progress fill from the base, with a leading node.
                let cur = start + sweep * max(0, min(1, fraction))
                line(arc(start, max(start + 0.01, cur)))
                dot(point(cur), dotR)

            case .flowmodoro:
                // Open-ended: a steady node at the apex (no fraction).
                line(arc(-26, 26), opacity: 0.9)
                dot(point(0), dotR)

            case .overflow:
                // Full track plus a second mark just past the end base.
                line(arc(start, end))
                let endPoint = point(end)
                let second = arc(end - 30, end)
                    .applying(.init(translationX: (endPoint.x - center.x) * 0.32,
                                    y: (endPoint.y - center.y) * 0.32))
                line(second, opacity: 0.85)
                dot(endPoint, dotR)

            case .ended:
                // Resolved gauge with a centre decision node.
                line(arc(start, end), width: stroke + 0.2 * scale)
                dot(point(end), dotR)
                dot(center, dotR * 0.7, opacity: 0.9)
            }
        }
    }
}
