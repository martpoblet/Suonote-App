import SwiftUI

struct AudioEffectsSheet: View {
    @Binding var settings: AudioEffectsProcessor.EffectSettings
    @Environment(\.dismiss) private var dismiss
    let onApply: () -> Void
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Reverb Section
                    EffectSection(
                        title: "Reverb",
                        icon: "waveform.path.ecg",
                        color: .purple,
                        isEnabled: $settings.reverbEnabled
                    ) {
                        VStack(spacing: 16) {
                            SliderControl(
                                title: "Mix",
                                value: $settings.reverbMix,
                                range: 0...1,
                                icon: "speaker.wave.2"
                            )
                            
                            SliderControl(
                                title: "Room Size",
                                value: $settings.reverbSize,
                                range: 0...1,
                                icon: "square.resize"
                            )
                        }
                    }
                    
                    // Delay Section
                    EffectSection(
                        title: "Delay",
                        icon: "arrow.triangle.2.circlepath",
                        color: .blue,
                        isEnabled: $settings.delayEnabled
                    ) {
                        VStack(spacing: 16) {
                            SliderControl(
                                title: "Time",
                                value: $settings.delayTime,
                                range: 0.1...2.0,
                                icon: "timer",
                                format: "%.2fs"
                            )
                            
                            SliderControl(
                                title: "Feedback",
                                value: $settings.delayFeedback,
                                range: 0...0.9,
                                icon: "repeat"
                            )
                            
                            SliderControl(
                                title: "Mix",
                                value: $settings.delayMix,
                                range: 0...1,
                                icon: "speaker.wave.2"
                            )
                        }
                    }
                    
                    // EQ Section
                    EffectSection(
                        title: "Equalizer",
                        icon: "slider.horizontal.3",
                        color: .green,
                        isEnabled: $settings.eqEnabled
                    ) {
                        VStack(spacing: 16) {
                            SliderControl(
                                title: "Low (80 Hz)",
                                value: $settings.lowGain,
                                range: -24...24,
                                icon: "waveform.path",
                                format: "%.0f dB"
                            )
                            
                            SliderControl(
                                title: "Mid (1 kHz)",
                                value: $settings.midGain,
                                range: -24...24,
                                icon: "waveform.path",
                                format: "%.0f dB"
                            )
                            
                            SliderControl(
                                title: "High (10 kHz)",
                                value: $settings.highGain,
                                range: -24...24,
                                icon: "waveform.path",
                                format: "%.0f dB"
                            )
                        }
                    }
                    
                    // Compression Section
                    EffectSection(
                        title: "Compression",
                        icon: "waveform.badge.minus",
                        color: .orange,
                        isEnabled: $settings.compressionEnabled
                    ) {
                        VStack(spacing: 16) {
                            SliderControl(
                                title: "Threshold",
                                value: $settings.compressionThreshold,
                                range: -60...0,
                                icon: "level",
                                format: "%.0f dB"
                            )
                            
                            SliderControl(
                                title: "Ratio",
                                value: $settings.compressionRatio,
                                range: 1...20,
                                icon: "dial.low",
                                format: "%.1f:1"
                            )
                        }
                    }
                    
                    // Apply Button
                    Button {
                        onApply()
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Apply Effects")
                                .font(DesignSystem.Typography.headline)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    }
                }
                .padding(24)
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.15),
                        Color(red: 0.1, green: 0.05, blue: 0.2),
                        Color.black
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .navigationTitle("Audio Effects")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        resetAll()
                    } label: {
                        Text("Reset")
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func resetAll() {
        settings = AudioEffectsProcessor.EffectSettings()
    }
}

// MARK: - Effect Section

struct EffectSection<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @Binding var isEnabled: Bool
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle(isOn: $isEnabled) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(DesignSystem.Typography.title3)
                        .foregroundStyle(color)
                        .frame(width: 32)
                    
                    Text(title)
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(.white)
                }
            }
            .tint(color)
            
            if isEnabled {
                content
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isEnabled ? color.opacity(0.5) : Color.white.opacity(0.1), lineWidth: isEnabled ? 2 : 1)
                )
        )
        .animation(.spring(response: 0.3), value: isEnabled)
    }
}

// MARK: - Slider Control

struct SliderControl: View {
    let title: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let icon: String
    var format: String = "%.2f"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
                
                Text(title)
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Text(String(format: format, value))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            
            Slider(value: $value, in: range)
                .tint(.purple)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
        )
    }
}

#Preview {
    AudioEffectsSheet(
        settings: .constant(AudioEffectsProcessor.EffectSettings()),
        onApply: {}
    )
}
