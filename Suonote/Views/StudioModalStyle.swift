import SwiftUI

extension View {
    /// Shared chrome for app sheets: paper background, visible grabber,
    /// generous corner radius. On iOS 26 the system supplies the glass edge.
    func studioModalStyle() -> some View {
        self
            .presentationBackground(DesignSystem.Colors.background)
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
    }
}

/// Consistent scaffold for every modal in the app:
/// Erode title + italic subtitle, glass close button, scrolling body,
/// and an optional pinned primary action.
struct SheetScaffold<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    var primaryTitle: String? = nil
    var primaryIcon: String? = nil
    var primaryDisabled: Bool = false
    var primaryAction: (() -> Void)? = nil
    var scrolls: Bool = true
    @ViewBuilder let content: Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, DesignSystem.Spacing.gutter)
                .padding(.top, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.sm)

            if scrolls {
                ScrollView {
                    content
                        .padding(.horizontal, DesignSystem.Spacing.gutter)
                        .padding(.top, DesignSystem.Spacing.xs)
                        .padding(.bottom, DesignSystem.Spacing.xxl)
                }
                .scrollIndicators(.hidden)
            } else {
                content
                    .padding(.horizontal, DesignSystem.Spacing.gutter)
                Spacer(minLength: 0)
            }

            if let primaryTitle, let primaryAction {
                PrimaryButton(primaryTitle, icon: primaryIcon, action: primaryAction)
                    .disabled(primaryDisabled)
                    .padding(.horizontal, DesignSystem.Spacing.gutter)
                    .padding(.vertical, DesignSystem.Spacing.sm)
            }
        }
        .background(DesignSystem.Colors.background.ignoresSafeArea())
    }

    private var header: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(DesignSystem.Typography.title)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(DesignSystem.Typography.italicSmall)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
            Spacer(minLength: 0)
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Close")
        }
    }
}
