import AppKit
import SwiftUI

@MainActor
enum GlassWindow {
    /// Configures `window` as a headless, frosted-glass card: no title-bar plate,
    /// floating traffic lights over full-height content, rounded corners, and a
    /// clear/non-opaque backing so the `NSVisualEffectView` that `host(_:in:)`
    /// installs as the contentView reads through to the desktop. The window then
    /// reads as a single Liquid-Glass surface, not a chromed document window.
    static func makeHeadless(
        size: NSSize,
        resizable: Bool,
        title: String,
        delegate: NSWindowDelegate
    ) -> NSWindow {
        var mask: NSWindow.StyleMask = [.titled, .closable, .fullSizeContentView]
        if resizable { mask.insert(.miniaturizable); mask.insert(.resizable) }

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: mask,
            backing: .buffered,
            defer: false
        )
        window.title = title                       // kept for the window menu / a11y only
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true   // no title-bar plate or separator
        window.isMovableByWindowBackground = true  // drag anywhere — there's no title bar
        window.backgroundColor = .clear
        window.isOpaque = false
        window.isReleasedWhenClosed = false        // the controller holds the reference
        window.delegate = delegate
        // The floating traffic lights are the only visible chrome; the resize
        // control stays available on the resizable dashboard via window edges.
        return window
    }

    /// The top inset that keeps content clear of the floating traffic-light
    /// cluster in a full-size-content-view window.
    static let trafficLightInset: CGFloat = 30

    /// Installs the frosted glass and hosts `root` on top of it.
    ///
    /// The window's whole `contentView` is an `NSVisualEffectView` with
    /// behind-window vibrancy — so the glass fills the entire window, *including
    /// the (transparent) title-bar region*. Earlier the vibrancy was a SwiftUI
    /// `.background`, which SwiftUI inset below the title bar; the uncovered top
    /// strip then showed the clear window backing (the desktop), reading as a
    /// stray "top bar". Filling the contentView removes that band, so the window
    /// is one continuous Liquid-Glass surface (matching the popover). The
    /// `NSHostingView` sits on top with a cleared layer (it paints opaque by
    /// default, which would otherwise hide the vibrancy). Rounded corners come
    /// from the window's native shape (titled + clear/non-opaque). The system
    /// flattens the vibrancy automatically under Reduce Transparency.
    static func host(_ root: some View, in window: NSWindow) {
        let glass = NSVisualEffectView()
        glass.material = .popover            // matches the menu-bar popover's glass
        glass.blendingMode = .behindWindow
        glass.state = .active
        // Round ALL four corners. A titled window's frame rounds its shadow and
        // the bottom corners, but a `.behindWindow` vibrancy filling a
        // full-size-content, clear/non-opaque window composites its TOP corners
        // square — reading as a rectangular plate poking out of a rounded
        // window. A resizable rounded mask image clips the vibrancy (and its
        // behind-window sampling + shadow) to the design's r-lg corner.
        glass.maskImage = Self.roundedMask(radius: PlyneRadius.lg)

        // The popover gets a subtle light rim + top highlight from the system;
        // this hand-built window must add the same edge so it reads as the same
        // Liquid-Glass surface, not a flat translucent rectangle.
        let hosting = NSHostingView(rootView: root.modifier(GlassEdge()))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = .clear
        glass.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: glass.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: glass.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: glass.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: glass.bottomAnchor)
        ])
        window.contentView = glass
    }

    /// A black rounded-rect image with cap insets, so a single small bitmap
    /// stretches to mask an `NSVisualEffectView` of any size with a constant
    /// corner radius (works as the window resizes).
    private static func roundedMask(radius: CGFloat) -> NSImage {
        let side = radius * 2 + 1
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}

/// The Liquid-Glass edge for the headless windows: a hairline light rim around
/// the rounded shape plus a faint top-inner highlight — the same finish the
/// system gives the menu-bar popover (the design's `--glass-stroke` +
/// `inset 0 1px 0 rgba(255,255,255,.5)`), so the dashboard and onboarding read
/// as the same surface. Adapts to light/dark and recedes under Reduce
/// Transparency; never intercepts hits.
private struct GlassEdge: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var rimOpacity: Double {
        if reduceTransparency { return scheme == .dark ? 0.22 : 0.30 }
        return scheme == .dark ? 0.16 : 0.55
    }

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: PlyneRadius.lg, style: .continuous)
        content
            .overlay {
                shape
                    .strokeBorder(Color.white.opacity(rimOpacity), lineWidth: 1)
                    .blendMode(scheme == .dark ? .plusLighter : .normal)
                    .allowsHitTesting(false)
            }
            .ignoresSafeArea()
    }
}
