import SwiftUI
import AVFoundation
import UIKit

/// Full-screen capture: set up (type, section, count-in, click), then one big
/// record button. Count-in and the click come from the recording manager's
/// metronome so what you hear and what you see are the same clock.
struct ActiveRecordingView: View {
    @Bindable var project: Project
    @ObservedObject var audioManager: AudioRecordingManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedRecordingType: RecordingType
    @State private var selectedLinkedSectionId: UUID?
    @State private var liveLevels: [Float] = Array(repeating: 0, count: 64)
    @State private var micDenied = false
    @State private var showingCloseOptions = false
    @State private var showingDiscardConfirm = false
    @State private var recPulse = false

    @AppStorage(RecordPreferenceKey.countInBars) private var countInBars = 1
    @AppStorage(RecordPreferenceKey.clickEnabled) private var clickEnabled = false
    @AppStorage(RecordPreferenceKey.lastType) private var lastTypeRaw = RecordingType.voice.rawValue

    private let autoStart: Bool

    init(
        project: Project,
        audioManager: AudioRecordingManager,
        recordingType: RecordingType,
        initialLinkedSectionId: UUID? = nil,
        autoStart: Bool = false
    ) {
        self.project = project
        self.audioManager = audioManager
        self.autoStart = autoStart
        self._selectedRecordingType = State(initialValue: recordingType)
        self._selectedLinkedSectionId = State(initialValue: initialLinkedSectionId)
    }

    private enum Phase { case ready, countIn, recording }

    private var phase: Phase {
        if audioManager.isRecording { return .recording }
        if audioManager.isCountingIn { return .countIn }
        return .ready
    }

    private var uniqueSections: [SectionTemplate] { project.recordUniqueSections }

    private var selectedLinkedSection: SectionTemplate? {
        guard let selectedLinkedSectionId else { return nil }
        return uniqueSections.first { $0.id == selectedLinkedSectionId }
    }

    private var beatsPerBar: Int { max(1, project.tempoBeatsPerBar) }
    private var takeNumber: Int { project.recordings.count + 1 }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, DesignSystem.Spacing.gutter)
                .padding(.top, DesignSystem.Spacing.xs)

            Group {
                switch phase {
                case .ready: readyView
                case .countIn: countInView
                case .recording: recordingView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, DesignSystem.Spacing.gutter)
            .animation(DesignSystem.Animations.smoothSpring, value: phase)

            transport
                .padding(.horizontal, DesignSystem.Spacing.gutter)
                .padding(.bottom, DesignSystem.Spacing.md)
        }
        .background(DesignSystem.Colors.background.ignoresSafeArea())
        .overlay(alignment: .top) {
            // A thin red rule while the tape is rolling.
            if phase == .recording {
                Rectangle()
                    .fill(DesignSystem.Colors.record)
                    .frame(height: 3)
                    .ignoresSafeArea(edges: .top)
                    .transition(.opacity)
            }
        }
        .onReceive(audioManager.$currentMeterLevel) { level in
            guard audioManager.isRecording else { return }
            liveLevels.removeFirst()
            liveLevels.append(level)
        }
        .onChange(of: audioManager.countInBeatsRemaining) { _, remaining in
            if remaining > 0 { HapticFeedback.light.trigger() }
        }
        .task {
            await checkMicrophone()
            if autoStart, !micDenied, !audioManager.isBusy {
                start()
            }
        }
        .onDisappear {
            // Never lose a take: anything still rolling is kept.
            if audioManager.isRecording {
                audioManager.stopRecording()
            } else if audioManager.isCountingIn {
                audioManager.cancelRecording()
            }
        }
        .confirmationDialog("Keep this take?", isPresented: $showingCloseOptions, titleVisibility: .visible) {
            Button("Save take") { stopAndSave() }
            Button("Discard take", role: .destructive) { discard() }
            Button("Keep recording", role: .cancel) {}
        }
        .confirmationDialog("Discard this take?", isPresented: $showingDiscardConfirm, titleVisibility: .visible) {
            Button("Discard take", role: .destructive) { discard() }
            Button("Keep recording", role: .cancel) {}
        } message: {
            Text("The audio recorded so far will be deleted.")
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Button {
                close()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Close")

            Spacer(minLength: 0)

            VStack(spacing: 2) {
                Text("Take \(takeNumber)")
                    .eyebrow(color: phase == .recording ? DesignSystem.Colors.record : DesignSystem.Colors.textTertiary)
                Text(project.title)
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: 0)

            // Balances the close button.
            Color.clear.frame(width: 36, height: 36)
        }
    }

    // MARK: Ready

    private var readyView: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.xl) {
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Text("0:00")
                        .font(DesignSystem.Typography.mega)
                        .monospacedDigit()
                        .foregroundStyle(DesignSystem.Colors.textTertiary.opacity(0.6))
                        .accessibilityHidden(true)
                    Text(readySummary)
                        .font(DesignSystem.Typography.italicSmall)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, DesignSystem.Spacing.xl)

                if micDenied {
                    micDeniedCard
                }

                optionsCard
            }
            .padding(.bottom, DesignSystem.Spacing.md)
        }
        .scrollIndicators(.hidden)
        .transition(.opacity)
    }

    private var readySummary: String {
        var parts = ["\(project.bpm) BPM", "\(project.timeTop)/\(project.timeBottom)"]
        switch countInBars {
        case 0: parts.append(String(localized: "no count-in"))
        default: parts.append(String(localized: "\(countInBars)-bar count-in"))
        }
        return parts.joined(separator: " · ")
    }

    private var optionsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            optionRow(title: "Type") {
                ScrollView(.horizontal) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        ForEach(RecordingType.allCases, id: \.self) { type in
                            SelectableChip(
                                title: type.recordDisplayName,
                                icon: type.icon,
                                isSelected: selectedRecordingType == type
                            ) {
                                HapticFeedback.selection.trigger()
                                selectedRecordingType = type
                                lastTypeRaw = type.rawValue
                            }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.md)
                }
                .scrollIndicators(.hidden)
                .padding(.horizontal, -DesignSystem.Spacing.md)
            }

            if !uniqueSections.isEmpty {
                Hairline()
                optionRow(title: "Section") {
                    ScrollView(.horizontal) {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            SelectableChip(title: String(localized: "None"), isSelected: selectedLinkedSectionId == nil) {
                                HapticFeedback.selection.trigger()
                                selectedLinkedSectionId = nil
                            }
                            ForEach(uniqueSections) { section in
                                SelectableChip(
                                    title: section.name,
                                    dot: section.color,
                                    isSelected: selectedLinkedSectionId == section.id
                                ) {
                                    HapticFeedback.selection.trigger()
                                    selectedLinkedSectionId = section.id
                                }
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.md)
                    }
                    .scrollIndicators(.hidden)
                    .padding(.horizontal, -DesignSystem.Spacing.md)
                }
            }

            Hairline()
            optionRow(title: "Count-in") {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    ForEach([0, 1, 2], id: \.self) { bars in
                        SelectableChip(
                            title: bars == 0 ? String(localized: "Off") : String(localized: "\(bars) bars"),
                            isSelected: countInBars == bars
                        ) {
                            HapticFeedback.selection.trigger()
                            countInBars = bars
                        }
                    }
                }
            }

            Hairline()
            Toggle(isOn: $clickEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Click while recording")
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Text(clickEnabled ? "Use headphones so the click stays off the take." : "The count-in always clicks.")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
            }
            .tint(DesignSystem.Colors.primary)
            .padding(DesignSystem.Spacing.md)
        }
        .cardStyle()
    }

    private func optionRow<Content: View>(title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(title).eyebrow()
            content()
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var micDeniedCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Label("Microphone access is off", systemImage: "mic.slash")
                .font(DesignSystem.Typography.subheadline)
                .foregroundStyle(DesignSystem.Colors.record)
            Text("Suonote needs the microphone to record takes. Turn it on in Settings.")
                .font(DesignSystem.Typography.callout)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(OutlineButtonStyle(compact: true))
            .padding(.top, DesignSystem.Spacing.xxs)
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(color: DesignSystem.Colors.record.opacity(0.4))
    }

    // MARK: Count-in

    private var countInView: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer(minLength: 0)
            Text("Count-in").eyebrow()
            Text("\(audioManager.countInBeatsRemaining)")
                .font(DesignSystem.Typography.hero)
                .monospacedDigit()
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .contentTransition(.numericText(countsDown: true))
                .animation(DesignSystem.Animations.quickSpring, value: audioManager.countInBeatsRemaining)
                .accessibilityLabel("Count-in, \(audioManager.countInBeatsRemaining)")

            let elapsedInBar = (countInBars * beatsPerBar - audioManager.countInBeatsRemaining) % beatsPerBar
            beatDots(active: elapsedInBar, tint: DesignSystem.Colors.textPrimary)

            Text("Recording starts on one.")
                .font(DesignSystem.Typography.italicSmall)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            Spacer(minLength: 0)
        }
        .transition(.opacity)
    }

    // MARK: Recording

    private var recordingView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Spacer(minLength: 0)

            HStack(spacing: 6) {
                Circle()
                    .fill(DesignSystem.Colors.record)
                    .frame(width: 8, height: 8)
                    .opacity(recPulse ? 0.35 : 1)
                Text("Recording")
                    .eyebrow(color: DesignSystem.Colors.record)
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { recPulse = true }
            }

            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(RecordFormat.elapsedMain(audioManager.elapsedTime))
                    .font(DesignSystem.Typography.mega)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Text(RecordFormat.elapsedTenths(audioManager.elapsedTime))
                    .font(DesignSystem.Typography.title)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
            .monospacedDigit()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Elapsed \(RecordFormat.spoken(audioManager.elapsedTime))")

            VStack(spacing: DesignSystem.Spacing.xs) {
                let bar = audioManager.recordedBeats / beatsPerBar + 1
                let beat = audioManager.recordedBeats % beatsPerBar
                Text("Bar \(bar) · Beat \(beat + 1)")
                    .font(DesignSystem.Typography.calloutBold)
                    .monospacedDigit()
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                beatDots(active: beat, tint: DesignSystem.Colors.primary)
            }
            .accessibilityElement(children: .combine)

            VStack(spacing: DesignSystem.Spacing.sm) {
                RecordLiveWaveform(levels: liveLevels)
                    .frame(height: 120)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .wellStyle(cornerRadius: DesignSystem.CornerRadius.card)

                HStack(spacing: DesignSystem.Spacing.sm) {
                    Text("Input").eyebrow()
                    AudioLevelMeter(
                        level: audioManager.currentMeterLevel,
                        peakLevel: audioManager.currentPeakLevel,
                        orientation: .horizontal,
                        showClipping: false,
                        thickness: 6
                    )
                    Text(audioManager.currentPeakLevel >= 0.95 ? "Clip" : "OK")
                        .eyebrow(color: audioManager.currentPeakLevel >= 0.95 ? DesignSystem.Colors.record : DesignSystem.Colors.primaryDark)
                        .frame(width: 32, alignment: .trailing)
                }
            }

            if let section = selectedLinkedSection {
                AppChip(text: section.name, icon: "link", tint: section.color)
            }

            Spacer(minLength: 0)
        }
        .transition(.opacity)
    }

    private func beatDots(active: Int, tint: Color) -> some View {
        HStack(spacing: 10) {
            ForEach(0..<beatsPerBar, id: \.self) { beat in
                Circle()
                    .fill(beat <= active ? tint : DesignSystem.Colors.border)
                    .frame(width: beat == 0 ? 12 : 9, height: beat == 0 ? 12 : 9)
                    .scaleEffect(beat == active && !reduceMotion ? 1.25 : 1)
                    .animation(DesignSystem.Animations.quickSpring, value: active)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: Transport

    private var transport: some View {
        HStack {
            // Leading: discard while rolling
            Group {
                if phase == .recording {
                    Button {
                        HapticFeedback.warning.trigger()
                        showingDiscardConfirm = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .frame(width: 52, height: 52)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .accessibilityLabel("Discard take")
                } else {
                    Color.clear
                }
            }
            .frame(width: 60, height: 60)

            Spacer()

            RecordBigButton(state: recordButtonState) {
                switch phase {
                case .ready: start()
                case .countIn: cancelCountIn()
                case .recording: stopAndSave()
                }
            }
            .disabled(micDenied && phase == .ready)
            .opacity(micDenied && phase == .ready ? 0.4 : 1)

            Spacer()

            // Balances the discard button.
            Color.clear.frame(width: 60, height: 60)
        }
        .overlay(alignment: .bottom) {
            Text(transportHint)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .offset(y: 22)
                .accessibilityHidden(true)
        }
        .padding(.bottom, DesignSystem.Spacing.lg)
    }

    private var recordButtonState: RecordBigButton.ButtonState {
        switch phase {
        case .ready: return .idle
        case .countIn: return .armed
        case .recording: return .recording
        }
    }

    private var transportHint: String {
        switch phase {
        case .ready: return String(localized: "Tap to record")
        case .countIn: return String(localized: "Tap to cancel")
        case .recording: return String(localized: "Tap to stop and save")
        }
    }

    // MARK: Actions

    private func start() {
        guard !audioManager.isBusy else { return }
        HapticFeedback.medium.trigger()
        liveLevels = Array(repeating: 0, count: liveLevels.count)
        recPulse = false
        audioManager.setup(project: project)
        audioManager.startRecording(
            countIn: countInBars,
            clickEnabled: clickEnabled,
            recordingType: selectedRecordingType,
            linkedSectionId: selectedLinkedSectionId
        )
    }

    private func cancelCountIn() {
        HapticFeedback.light.trigger()
        audioManager.cancelRecording()
    }

    private func stopAndSave() {
        audioManager.stopRecording()
        HapticFeedback.success.trigger()
        dismiss()
    }

    private func discard() {
        audioManager.cancelRecording()
        HapticFeedback.warning.trigger()
        dismiss()
    }

    private func close() {
        switch phase {
        case .recording:
            showingCloseOptions = true
        case .countIn:
            audioManager.cancelRecording()
            dismiss()
        case .ready:
            dismiss()
        }
    }

    private func checkMicrophone() async {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            micDenied = false
        case .denied:
            micDenied = true
        default:
            let granted = await AVAudioApplication.requestRecordPermission()
            micDenied = !granted
        }
    }
}

// MARK: - Big record button

/// The unmistakable record control: a red disc that morphs into a stop
/// square while rolling.
struct RecordBigButton: View {
    enum ButtonState { case idle, armed, recording }

    let state: ButtonState
    var size: CGFloat = 84
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(DesignSystem.Colors.textPrimary.opacity(0.85), lineWidth: 3.5)
                    .frame(width: size, height: size)

                RoundedRectangle(cornerRadius: state == .idle ? size * 0.36 : size * 0.1, style: .continuous)
                    .fill(DesignSystem.Colors.record)
                    .frame(
                        width: state == .idle ? size * 0.72 : size * 0.36,
                        height: state == .idle ? size * 0.72 : size * 0.36
                    )
                    .opacity(state == .armed ? 0.55 : 1)
            }
            .frame(width: size + 8, height: size + 8)
            .contentShape(Circle())
            .animation(DesignSystem.Animations.bouncy, value: state)
        }
        .buttonStyle(AnimatedPressButtonStyle(scale: 0.92))
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        switch state {
        case .idle: return String(localized: "Record")
        case .armed: return String(localized: "Cancel count-in")
        case .recording: return String(localized: "Stop and save take")
        }
    }
}
