import SwiftUI

// Liquid Glass is confined to the action/control layer (per the concept's
// "glass on the control layer only" rule). Both styles fall back to solid
// bordered buttons when the user has reduced transparency or increased
// contrast — translucency they have opted out of.

/// A prominent primary action.
struct PrimaryButton: View {
    let titleKey: LocalizedStringKey
    let action: () -> Void
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    init(_ titleKey: LocalizedStringKey, action: @escaping () -> Void) {
        self.titleKey = titleKey
        self.action = action
    }

    private var solid: Bool { reduceTransparency || contrast == .increased }

    var body: some View {
        if solid {
            Button(titleKey, action: action).buttonStyle(.borderedProminent)
        } else {
            Button(titleKey, action: action).buttonStyle(.glassProminent)
        }
    }
}

/// A secondary action; glass when available, bordered otherwise.
struct SecondaryButton: View {
    let titleKey: LocalizedStringKey
    let action: () -> Void
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    init(_ titleKey: LocalizedStringKey, action: @escaping () -> Void) {
        self.titleKey = titleKey
        self.action = action
    }

    private var solid: Bool { reduceTransparency || contrast == .increased }

    var body: some View {
        if solid {
            Button(titleKey, action: action).buttonStyle(.bordered)
        } else {
            Button(titleKey, action: action).buttonStyle(.glass)
        }
    }
}
