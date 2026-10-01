import SwiftUI

/// Credits for the bundled SoundFont (MS Basic, MIT).
struct SoundFontCreditsView: View {
    private let upstreamURL = URL(string: "https://ftp.osuosl.org/pub/musescore/soundfont/MuseScore_General/")!

    var body: some View {
        SheetScaffold(title: String(localized: "Sound credits"), subtitle: String(localized: "The instruments behind every playback.")) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        ZStack {
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                                .fill(DesignSystem.Colors.primaryLight)
                                .frame(width: 44, height: 44)
                            Image(systemName: "pianokeys")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(DesignSystem.Colors.primaryDark)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: "MS Basic SoundFont")
                                .font(DesignSystem.Typography.headline)
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                            Text("MuseScore · MIT license")
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }
                    }
                    Hairline()
                    Text("Suonote plays your songs with the MS Basic SoundFont from MuseScore (formerly MuseScore General). It is based on FluidR3 by Frank Wen, with extensive additions and curation by S. Christian Collins and the MuseScore community.")
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Link(destination: upstreamURL) {
                        Label { Text(verbatim: "MuseScore General SoundFont") } icon: { Image(systemName: "arrow.up.right") }
                    }
                    .buttonStyle(OutlineButtonStyle(compact: true))
                }
                .padding(DesignSystem.Spacing.md)
                .cardStyle()

                LibraryFormGroup(title: String(localized: "License")) {
                    Text(verbatim: "MIT License. Copyright © FluidR3 by Frank Wen; MuseScore General additions © S. Christian Collins and contributors. Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files, to deal in the software without restriction. See THIRD_PARTY_NOTICES for the full text.")
                        .font(DesignSystem.Typography.footnote)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(DesignSystem.Spacing.md)
                        .wellStyle()
                }

                Text("Thank you for making music free to make.")
                    .font(DesignSystem.Typography.italicSmall)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
        .presentationDetents([.medium, .large])
        .studioModalStyle()
    }
}

#Preview {
    Text("Host").sheet(isPresented: .constant(true)) { SoundFontCreditsView() }
}
