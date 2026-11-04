import SwiftUI

/// A quiet invitation to rate Suonote, shown in the Library after the person has
/// used the app for a while (see `ReviewPrompt`). It never blocks anything:
/// "Not now" simply dismisses it.
struct ReviewPromptCard: View {
    let onRate: () -> Void
    let onLater: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.primary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    Text("Enjoying Suonote?")
                        .font(DesignSystem.Typography.calloutBold)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Text("A quick rating helps other songwriters find it and keeps us building.")
                        .font(DesignSystem.Typography.footnote)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: DesignSystem.Spacing.sm) {
                Button(action: onRate) {
                    Label("Rate Suonote", systemImage: "star.fill")
                        .font(DesignSystem.Typography.buttonSmall)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.glassProminent)
                .tint(DesignSystem.Colors.primary)

                Button(action: onLater) {
                    Text("Not now")
                        .font(DesignSystem.Typography.buttonSmall)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .frame(minWidth: 80, minHeight: 44)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .cardStyle()
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    ReviewPromptCard(onRate: {}, onLater: {})
        .padding()
        .paperBackground()
}
