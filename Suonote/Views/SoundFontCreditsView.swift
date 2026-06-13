import SwiftUI

struct SoundFontCreditsView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    Text("SoundFont Credits")
                        .font(DesignSystem.Typography.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("This app includes the MS Basic SoundFont from MuseScore (formerly MuseScore General).")
                        Text("MS Basic is based on FluidR3 by Frank Wen, with extensive additions and curation by S. Christian Collins and the MuseScore community.")
                        Text("It is distributed under the MIT license.")
                    }
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Upstream documentation")
                            .font(DesignSystem.Typography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)

                        Link(
                            "MuseScore General SoundFont",
                            destination: URL(string: "https://ftp.osuosl.org/pub/musescore/soundfont/MuseScore_General/")!
                        )
                        .font(DesignSystem.Typography.callout)
                    }

                    Divider()

                    Text("License")
                        .font(DesignSystem.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)

                    Text("MIT License. Copyright © FluidR3 by Frank Wen; MuseScore General additions © S. Christian Collins and contributors. Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files, to deal in the software without restriction. See THIRD_PARTY_NOTICES for the full text.")
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
