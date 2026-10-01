import SwiftUI

// MARK: - Style card

/// Editorial card for one Studio style: Erode name, italic one-liner, the
/// style's accent used only as a small mark.
struct StudioStyleCard: View {
    let style: StudioStyle
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                HStack(alignment: .top) {
                    ZStack {
                        Circle().fill(style.accentColor.opacity(0.18))
                        Image(systemName: style.icon)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                    }
                    .frame(width: 34, height: 34)
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(isSelected ? DesignSystem.Colors.primaryDark : DesignSystem.Colors.borderActive)
                }
                .padding(.bottom, 4)

                Text(style.title)
                    .font(DesignSystem.Typography.title3)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .lineLimit(1)
                Text(style.description)
                    .font(DesignSystem.Typography.italicSmall)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Capsule()
                    .fill(style.accentColor)
                    .frame(width: 22, height: 3)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 156, alignment: .topLeading)
            .cardStyle(
                color: isSelected ? DesignSystem.Colors.textPrimary : nil,
                fill: isSelected ? style.accentColor.opacity(0.08) : DesignSystem.Colors.surface
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(style.title). \(style.description)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .animation(DesignSystem.Animations.quickSpring, value: isSelected)
    }
}

/// Two-column grid of all styles.
struct StudioStyleGrid: View {
    let selected: StudioStyle?
    let onSelect: (StudioStyle) -> Void

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            spacing: 12
        ) {
            ForEach(StudioStyle.allCases) { style in
                StudioStyleCard(style: style, isSelected: style == selected) {
                    onSelect(style)
                    haptic(.selection)
                }
            }
        }
    }
}

// MARK: - Style picker sheet

struct StudioStylePickerView: View {
    let selectedStyle: StudioStyle?
    var willRewriteTracks: Bool = false
    let onConfirm: (StudioStyle) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var currentSelection: StudioStyle?

    private var subtitle: String {
        willRewriteTracks
            ? String(localized: "Changing the style rewrites every generated part.")
            : String(localized: "It shapes the groove, voicings and sounds of every part.")
    }

    var body: some View {
        SheetScaffold(
            title: selectedStyle == nil ? String(localized: "Choose a style") : String(localized: "Studio style"),
            subtitle: subtitle,
            primaryTitle: primaryTitle,
            primaryDisabled: currentSelection == nil || currentSelection == selectedStyle,
            primaryAction: {
                guard let style = currentSelection else { return }
                onConfirm(style)
                haptic(.success)
                dismiss()
            }
        ) {
            StudioStyleGrid(selected: currentSelection) { currentSelection = $0 }
        }
        .onAppear { currentSelection = selectedStyle }
    }

    private var primaryTitle: String {
        if let currentSelection, currentSelection != selectedStyle {
            return String(localized: "Use \(currentSelection.title)")
        }
        return selectedStyle == nil ? String(localized: "Pick a style") : String(localized: "Current style")
    }
}
