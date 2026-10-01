import SwiftUI

/// Standalone effects editor: the pedalboard in a sheet with an Apply action.
/// (The take detail embeds the same `RecordPedalboard` inline, live.)
struct AudioEffectsSheet: View {
    @Binding var settings: AudioEffectsProcessor.EffectSettings
    @Environment(\.dismiss) private var dismiss
    let onApply: () -> Void

    var body: some View {
        SheetScaffold(
            title: String(localized: "Effects"),
            subtitle: subtitle,
            primaryTitle: String(localized: "Apply effects"),
            primaryIcon: "checkmark",
            primaryAction: {
                HapticFeedback.success.trigger()
                onApply()
                dismiss()
            }
        ) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                SectionHeader(
                    title: String(localized: "Pedalboard"),
                    detail: String(localized: "EQ → Comp → Delay → Reverb"),
                    actionTitle: settings.recordActiveCount > 0 ? String(localized: "Reset") : nil,
                    action: settings.recordActiveCount > 0 ? { resetAll() } : nil
                )
                RecordPedalboard(settings: $settings)
            }
        }
        .presentationDetents([.large])
        .studioModalStyle()
    }

    private var subtitle: String {
        switch settings.recordActiveCount {
        case 0: return String(localized: "Everything bypassed — the dry take.")
        default: return String(localized: "\(settings.recordActiveCount) pedals on.")
        }
    }

    private func resetAll() {
        HapticFeedback.warning.trigger()
        withAnimation(DesignSystem.Animations.smoothSpring) {
            settings = AudioEffectsProcessor.EffectSettings()
        }
    }
}

#Preview {
    AudioEffectsSheet(
        settings: .constant(AudioEffectsProcessor.EffectSettings()),
        onApply: {}
    )
}
