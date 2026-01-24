import SwiftUI
import AVFoundation

struct RecordingDetailView: View {
    @Bindable var recording: Recording
    @Environment(\.dismiss) private var dismiss
    @StateObject private var effectsProcessor = AudioEffectsProcessor()
    @State private var isPlaying = false
    @State private var showingTypePicker = false
    @State private var editingName = false
    @State private var tempName = ""
    @State private var waveformHeights: [CGFloat] = (0..<50).map { _ in CGFloat.random(in: 20...80) }
    
    let sections: [SectionTemplate]
    let onUpdate: () -> Void
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header con waveform visual
                    waveformHeader
                    
                    // Info básica
                    basicInfoSection
                    
                    // Audio Effects
                    audioEffectsSection
                    
                    // Link Section
                    linkSectionView
                }
                .padding(24)
            }
            .background(
                LinearGradient(
                    colors: [
                        DesignSystem.Colors.backgroundSecondary,
                        DesignSystem.Colors.backgroundTertiary
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .navigationTitle("Edit Recording")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        onUpdate()
                        dismiss()
                    }
                }
            }
        }
        .toolbarBackground(DesignSystem.Colors.backgroundSecondary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .presentationBackground(DesignSystem.Colors.backgroundSecondary)
        .preferredColorScheme(.light)
        .presentationDetents([.large])
        .sheet(isPresented: $showingTypePicker) {
            RecordingTypePickerSheet(selectedType: Binding(
                get: { recording.recordingType },
                set: { recording.recordingType = $0 }
            ))
        }
        .onAppear {
            tempName = recording.name
            loadEffectsFromRecording()
        }
    }
    
    private var waveformHeader: some View {
        VStack(spacing: 16) {
            // Visual waveform placeholder
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            recording.recordingType.color.opacity(0.3),
                            recording.recordingType.color.opacity(0.1)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 100)
                .overlay(
                    HStack(spacing: 2) {
                        ForEach(waveformHeights.indices, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(recording.recordingType.color.opacity(0.6))
                                .frame(width: 3, height: waveformHeights[index])
                        }
                    }
                )
            
            HStack(spacing: 12) {
                Image(systemName: recording.recordingType.icon)
                    .font(DesignSystem.Typography.title2)
                    .foregroundStyle(recording.recordingType.color)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(recording.name)
                        .font(DesignSystem.Typography.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    
                    Text(formatDuration(recording.duration))
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
                
                Spacer()
                
                Button {
                    playWithEffects()
                } label: {
                    Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                        .font(DesignSystem.Typography.title2)
                        .foregroundStyle(recording.recordingType.color)
                }
            }
        }
    }
    
    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Basic Info")
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            
            // Name
            VStack(alignment: .leading, spacing: 8) {
                Text("Name")
                    .font(.subheadline)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                
                HStack {
                    TextField("Recording name", text: $tempName)
                        .textFieldStyle(.plain)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .onChange(of: tempName) { _, newValue in
                            recording.name = newValue
                        }
                    
                    if tempName != recording.name {
                        Button("Reset") {
                            tempName = recording.name
                        }
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.warning)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(DesignSystem.Colors.surfaceSecondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(DesignSystem.Colors.border, lineWidth: 1)
                        )
                )
            }
            
            // Type
            Button {
                showingTypePicker = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Recording Type")
                            .font(.subheadline)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                        
                        HStack(spacing: 8) {
                            Image(systemName: recording.recordingType.icon)
                            Text(recording.recordingType.rawValue)
                                .font(DesignSystem.Typography.subheadline)
                        }
                        .foregroundStyle(recording.recordingType.color)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(DesignSystem.Colors.surfaceSecondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(DesignSystem.Colors.border, lineWidth: 1)
                        )
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignSystem.Colors.surfaceSecondary)
        )
    }
    
    private var audioEffectsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Audio Effects")
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            
            // Reverb
            EffectToggle(
                title: "Reverb",
                icon: "waveform.path.ecg",
                color: DesignSystem.Colors.primary,
                isEnabled: Binding(
                    get: { recording.reverbEnabled },
                    set: { recording.reverbEnabled = $0 }
                )
            ) {
                VStack(spacing: 12) {
                    EffectSlider(
                        title: "Mix",
                        value: Binding(
                            get: { recording.reverbMix },
                            set: { recording.reverbMix = $0 }
                        ),
                        range: 0...1
                    )
                    
                    EffectSlider(
                        title: "Size",
                        value: Binding(
                            get: { recording.reverbSize },
                            set: { recording.reverbSize = $0 }
                        ),
                        range: 0...1
                    )
                }
            }
            
            // Delay
            EffectToggle(
                title: "Delay",
                icon: "arrow.triangle.2.circlepath",
                color: DesignSystem.Colors.info,
                isEnabled: Binding(
                    get: { recording.delayEnabled },
                    set: { recording.delayEnabled = $0 }
                )
            ) {
                VStack(spacing: 12) {
                    EffectSlider(
                        title: "Time",
                        value: Binding(
                            get: { recording.delayTime },
                            set: { recording.delayTime = $0 }
                        ),
                        range: 0.1...0.8,
                        format: "%.2fs"
                    )
                    
                    EffectSlider(
                        title: "Feedback",
                        value: Binding(
                            get: { recording.delayFeedback },
                            set: { recording.delayFeedback = $0 }
                        ),
                        range: 0...0.9
                    )
                    
                    EffectSlider(
                        title: "Mix",
                        value: Binding(
                            get: { recording.delayMix },
                            set: { recording.delayMix = $0 }
                        ),
                        range: 0...1
                    )
                }
            }
            
            // EQ
            EffectToggle(
                title: "Equalizer",
                icon: "slider.horizontal.3",
                color: DesignSystem.Colors.success,
                isEnabled: Binding(
                    get: { recording.eqEnabled },
                    set: { recording.eqEnabled = $0 }
                )
            ) {
                VStack(spacing: 12) {
                    EffectSlider(
                        title: "Low",
                        value: Binding(
                            get: { recording.lowGain },
                            set: { recording.lowGain = $0 }
                        ),
                        range: -24...24,
                        format: "%.0f dB"
                    )
                    
                    EffectSlider(
                        title: "Mid",
                        value: Binding(
                            get: { recording.midGain },
                            set: { recording.midGain = $0 }
                        ),
                        range: -24...24,
                        format: "%.0f dB"
                    )
                    
                    EffectSlider(
                        title: "High",
                        value: Binding(
                            get: { recording.highGain },
                            set: { recording.highGain = $0 }
                        ),
                        range: -24...24,
                        format: "%.0f dB"
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignSystem.Colors.surfaceSecondary)
        )
    }
    
    private var linkSectionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Link to Section")
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            
            if sections.isEmpty {
                Text("No sections available")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // Unlink button
                        if recording.linkedSectionId != nil {
                            Button {
                                recording.linkedSectionId = nil
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(DesignSystem.Typography.title2)
                                        .foregroundStyle(DesignSystem.Colors.error)
                                    
                                    Text("Unlink")
                                        .font(DesignSystem.Typography.caption)
                                }
                                .frame(width: 80, height: 80)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(DesignSystem.Colors.error.opacity(0.2))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(DesignSystem.Colors.error, lineWidth: 1.5)
                                        )
                                )
                            }
                        }
                        
                        ForEach(sections) { section in
                            Button {
                                recording.linkedSectionId = section.id
                            } label: {
                                VStack(spacing: 8) {
                                    Text(section.name)
                                        .font(.subheadline)
                                        .lineLimit(2)
                                    
                                    Text("\(section.bars) bars")
                                        .font(DesignSystem.Typography.caption2)
                                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                                }
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                                .frame(width: 100, height: 80)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(recording.linkedSectionId == section.id ? DesignSystem.Colors.primary.opacity(0.2) : DesignSystem.Colors.surfaceSecondary)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(recording.linkedSectionId == section.id ? DesignSystem.Colors.primary : DesignSystem.Colors.border, lineWidth: recording.linkedSectionId == section.id ? 2 : 1)
                                        )
                                )
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignSystem.Colors.surfaceSecondary)
        )
    }
    
    private func loadEffectsFromRecording() {
        effectsProcessor.settings.reverbEnabled = recording.reverbEnabled
        effectsProcessor.settings.reverbMix = recording.reverbMix
        effectsProcessor.settings.reverbSize = recording.reverbSize
        
        effectsProcessor.settings.delayEnabled = recording.delayEnabled
        effectsProcessor.settings.delayTime = recording.delayTime
        effectsProcessor.settings.delayFeedback = recording.delayFeedback
        effectsProcessor.settings.delayMix = recording.delayMix
        
        effectsProcessor.settings.eqEnabled = recording.eqEnabled
        effectsProcessor.settings.lowGain = recording.lowGain
        effectsProcessor.settings.midGain = recording.midGain
        effectsProcessor.settings.highGain = recording.highGain
        
        effectsProcessor.settings.compressionEnabled = recording.compressionEnabled
        effectsProcessor.settings.compressionThreshold = recording.compressionThreshold
        effectsProcessor.settings.compressionRatio = recording.compressionRatio
    }
    
    private func playWithEffects() {
        if isPlaying {
            effectsProcessor.stop()
            isPlaying = false
        } else {
            loadEffectsFromRecording()
            guard let url = FileManagerUtils.existingRecordingURL(for: recording.fileName) else {
                print("Recording file not found for: \(recording.fileName)")
                return
            }
            
            do {
                try effectsProcessor.playAudio(url: url) {
                    isPlaying = false
                }
                isPlaying = true
            } catch {
                print("Failed to play recording with effects: \(error)")
                isPlaying = false
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Effect Components

struct EffectToggle<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @Binding var isEnabled: Bool
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $isEnabled) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .foregroundStyle(color)
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                }
            }
            .tint(color)
            
            if isEnabled {
                content
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(DesignSystem.Colors.surfaceSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isEnabled ? color.opacity(0.5) : DesignSystem.Colors.border, lineWidth: 1)
                )
        )
    }
}

struct EffectSlider: View {
    let title: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    var format: String = "%.2f"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                Spacer()
                Text(String(format: format, value))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
            }
            
            Slider(value: $value, in: range)
                .tint(DesignSystem.Colors.primary)
        }
    }
}
