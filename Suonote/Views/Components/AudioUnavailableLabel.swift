import SwiftUI

/// Shown in place of a waveform / player when a take's audio file is not on
/// this device. Recording metadata syncs through iCloud, audio files do not.
struct AudioUnavailableLabel: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "icloud.slash")
                .font(.system(size: 12, weight: .semibold))
            Text("Audio not available on this device")
                .font(DesignSystem.Typography.caption)
                .lineLimit(2)
        }
        .foregroundStyle(DesignSystem.Colors.textSecondary)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Audio not available on this device"))
    }
}
