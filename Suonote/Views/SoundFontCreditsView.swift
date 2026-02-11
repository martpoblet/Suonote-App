import SwiftUI

struct SoundFontCreditsView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    Text("Arachno SoundFont Credits")
                        .font(DesignSystem.Typography.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("This app includes a Lite subset of Arachno SoundFont.")
                        Text("Arachno SoundFont is created by Maxime Abbey (Arachnosoft), used with permission.")
                        Text("The bundled Lite version keeps selected original instruments as-is.")
                    }
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Official website")
                            .font(DesignSystem.Typography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)

                        Link(
                            "https://www.arachnosoft.com/main/soundfont.php",
                            destination: URL(string: "https://www.arachnosoft.com/main/soundfont.php")!
                        )
                        .font(DesignSystem.Typography.callout)
                    }

                    Divider()

                    Text("Legal note")
                        .font(DesignSystem.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)

                    Text("Raw SoundFont files are included only for in-app playback.")
                        .font(DesignSystem.Typography.footnote)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
                .padding(DesignSystem.Spacing.xl)
            }
            .background(DesignSystem.Colors.background.ignoresSafeArea())
            .navigationTitle("Credits")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    SoundFontCreditsView()
}
