import SwiftUI

// MARK: - Liquid Glass Components (iOS 26)
/// Shared glass vocabulary. Glass is reserved for the floating control layer:
/// transports, FABs, palettes, toolbars. Content surfaces stay solid (cardStyle).

// MARK: - Floating Glass Bar

/// Capsule glass container for floating control clusters (transport, action bars).
struct FloatingGlassBar<Content: View>: View {
    var tint: Color? = nil
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            content
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .glassEffect(tint.map { Glass.regular.tint($0.opacity(0.25)) } ?? .regular, in: .capsule)
    }
}

// MARK: - Glass Chip

extension View {
    /// Interactive glass chip used for chord/section/option chips that float
    /// above scrolling content.
    func glassChip(tint: Color, interactive: Bool = true) -> some View {
        self
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xxs)
            .glassEffect(
                interactive
                    ? Glass.regular.tint(tint.opacity(0.35)).interactive()
                    : Glass.regular.tint(tint.opacity(0.35)),
                in: .capsule
            )
    }
}

