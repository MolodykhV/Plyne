import SwiftUI

/// The Pomodoro / Flowmodoro picker, styled to the design instead of the flat
/// stock `.segmented`: a frosted track with a raised, sliding "frost-hi" pill
/// under the selected mode. The pill is a more-opaque material with a soft
/// shadow and a hairline top highlight, so it reads as lifted. Glass stays on
/// this control layer; under Reduce Transparency the track and pill become
/// solid neutral fills, and Increase Contrast firms the borders.
struct ModeSegmented: View {
    @Binding var selection: PickerMode
    /// `true` (idle) stretches the two segments edge to edge; `false` (the retro
    /// row) lets the control hug its labels and sit at the trailing edge.
    var fillsWidth: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Namespace private var pill

    private let options: [(mode: PickerMode, key: LocalizedStringKey)] = [
        (.pomodoro, "mode.pomodoro"),
        (.flowmodoro, "mode.flowmodoro")
    ]

    private var increased: Bool { contrast == .increased }
    private var trackShape: RoundedRectangle { RoundedRectangle(cornerRadius: PlyneRadius.sm, style: .continuous) }
    private var pillShape: RoundedRectangle { RoundedRectangle(cornerRadius: PlyneRadius.sm - 2, style: .continuous) }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.mode) { option in
                segment(option.mode, option.key)
            }
        }
        .padding(2)
        .background {
            trackShape.fill(reduceTransparency ? AnyShapeStyle(Color.primary.opacity(0.06)) : AnyShapeStyle(.thinMaterial))
        }
        .overlay {
            trackShape.strokeBorder(Color.primary.opacity(increased ? 0.28 : 0.10), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("mode.picker.label"))
    }

    private func segment(_ mode: PickerMode, _ key: LocalizedStringKey) -> some View {
        let selected = selection == mode
        return Button {
            withAnimation(reduceMotion ? nil : PlyneMotion.ease()) { selection = mode }
        } label: {
            Text(key)
                .font(.system(size: 13, weight: selected ? .semibold : .medium))
                .foregroundStyle(selected ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                .frame(maxWidth: fillsWidth ? .infinity : nil)
                .padding(.vertical, 6)
                .padding(.horizontal, fillsWidth ? 0 : 12)
                .contentShape(Rectangle())
                .background {
                    if selected {
                        pillShape
                            .fill(reduceTransparency ? AnyShapeStyle(Color.primary.opacity(0.14)) : AnyShapeStyle(.regularMaterial))
                            .overlay(pillShape.strokeBorder(.white.opacity(0.4), lineWidth: 0.5))
                            .shadow(color: .black.opacity(0.16), radius: 2, y: 1)
                            .matchedGeometryEffect(id: "modePill", in: pill)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(key))
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
