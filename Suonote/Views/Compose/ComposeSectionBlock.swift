import SwiftUI
import SwiftData

/// Callbacks a section block needs from the page.
struct ComposeSectionActions {
    let onSlot: (ChordSlot) -> Void
    let onAudition: (ComposeChordValue) -> Void
    let onRecord: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onMove: (Int) -> Void
    let onDelete: () -> Void
    let onToggleFocus: () -> Void
    let isFocused: Bool
}

// MARK: - Section block
/// One section of the lead sheet, set like a page: number + Erode name with a
/// thin color rule, quiet metadata, linked takes, then the measures.
struct ComposeSectionBlock: View {
    @Bindable var project: Project
    let item: ArrangementItem
    @Bindable var section: SectionTemplate
    let position: Int
    let sectionCount: Int
    let recordings: [Recording]
    let playingBar: Int?
    let audioManager: AudioRecordingManager
    let actions: ComposeSectionActions

    @Environment(ComposeEditor.self) private var editor

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            header

            if !recordings.isEmpty {
                ComposeLinkedTakesRow(recordings: recordings, audioManager: audioManager, tint: section.color)
            }

            ChordGridView(
                section: section,
                project: project,
                playingBar: playingBar,
                onSlot: actions.onSlot,
                onAudition: actions.onAudition
            )

            footer
        }
        .padding(.vertical, DesignSystem.Spacing.md)
        .padding(.leading, DesignSystem.Spacing.md + 2)
        .padding(.trailing, DesignSystem.Spacing.md)
        .cardStyle()
        .overlay(alignment: .topLeading) {
            Capsule()
                .fill(section.color)
                .frame(width: 3, height: 34)
                .padding(.top, DesignSystem.Spacing.md + 4)
                .accessibilityHidden(true)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
            VStack(alignment: .leading, spacing: 3) {
                Text(String(format: "%02d", position))
                    .eyebrow(color: DesignSystem.Colors.textTertiary)
                Text(section.name)
                    .font(DesignSystem.Typography.title2)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .lineLimit(2)
                metaLine
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(section.name), section \(position) of \(sectionCount), \(section.bars) bars")

            Spacer(minLength: 0)

            ComposeIconButton(systemImage: "mic", label: String(localized: "Record a take for \(section.name)"), tint: DesignSystem.Colors.record) {
                actions.onRecord()
            }
            menu
        }
    }

    private var metaLine: some View {
        let beatsPerBar = project.timeTop
        let total = Double(section.bars * beatsPerBar)
        let used = ComposeChordOps.usedBeats(section, beatsPerBar: beatsPerBar)
        let percent = total > 0 ? Int((min(used, total) / total * 100).rounded()) : 0

        return ComposeFlowLayout(spacing: 6, lineSpacing: 6) {
            Text(percent == 0 ? String(localized: "\(section.bars) bars · empty") : String(localized: "\(section.bars) bars · \(percent)% written"))
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            if section.hasKeyChange {
                AppChip(
                    text: String(localized: "Key \(ComposeFormat.keyShort(root: section.effectiveKeyRoot, mode: section.effectiveKeyMode))"),
                    icon: "key",
                    tint: section.color,
                    font: DesignSystem.Typography.caption2
                )
            }
            if section.hasTempoChange {
                AppChip(text: "\(section.effectiveBpm) bpm", icon: "metronome", tint: section.color, font: DesignSystem.Typography.caption2)
            }
            ProgressionAnalysisBadge(section: section, project: project)
        }
        .padding(.top, 2)
    }

    private var menu: some View {
        Menu {
            Section {
                Button { actions.onEdit() } label: { Label("Edit section…", systemImage: "slider.horizontal.3") }
                Button { actions.onToggleFocus() } label: {
                    Label(actions.isFocused ? "Show all sections" : "Focus on this section",
                          systemImage: actions.isFocused ? "rectangle.grid.1x2" : "scope")
                }
                Button { actions.onDuplicate() } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
            }
            Section {
                Button { addBar() } label: { Label("Add bar", systemImage: "plus") }
                Menu {
                    repeatButtons
                } label: {
                    Label("Repeat bars", systemImage: "repeat")
                }
                if !section.chordEvents.isEmpty {
                    Button { clearChords() } label: { Label("Clear chords", systemImage: "eraser") }
                }
            }
            Section {
                if position > 1 {
                    Button { actions.onMove(-1) } label: { Label("Move earlier", systemImage: "arrow.up") }
                }
                if position < sectionCount {
                    Button { actions.onMove(1) } label: { Label("Move later", systemImage: "arrow.down") }
                }
            }
            Button(role: .destructive) { actions.onDelete() } label: {
                Label("Delete section", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel("More for \(section.name)")
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Button {
                haptic(.light)
                addBar()
            } label: {
                Label("Add bar", systemImage: "plus")
                    .font(DesignSystem.Typography.buttonSmall)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            .buttonStyle(.plain)

            Menu {
                repeatButtons
            } label: {
                Label("Repeat", systemImage: "repeat")
                    .font(DesignSystem.Typography.buttonSmall)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            .menuOrder(.fixed)
            .simultaneousGesture(TapGesture().onEnded { haptic(.light) })
            .accessibilityHint("Copies the last bars to the end of the section")

            Spacer(minLength: 0)

            if let slot = firstEmptySlot {
                Button {
                    actions.onSlot(slot)
                } label: {
                    Label("Write chords", systemImage: "music.note")
                        .font(DesignSystem.Typography.buttonSmall)
                        .foregroundStyle(DesignSystem.Colors.primaryDark)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the chord palette at the first empty beat")
            }
        }
        .padding(.top, 2)
    }

    private var firstEmptySlot: ChordSlot? {
        guard let next = ComposeChordOps.nextEmptySlot(in: section, afterBar: 0, beat: 0, beatsPerBar: project.timeTop) else {
            return nil
        }
        return ChordSlot(barIndex: next.bar, beatOffset: next.beat, sectionId: section.id)
    }

    /// Repeat choices for the end of the section. Each copies those bars
    /// (chords included) right after themselves.
    @ViewBuilder
    private var repeatButtons: some View {
        let options = ComposeRepeatOption.endings(of: section)
        Section("Repeat at the end") {
            ForEach(options) { option in
                Button {
                    repeatBars(option)
                } label: {
                    Label(option.title, systemImage: option.icon)
                }
                .disabled(!ComposeChordOps.canAdd(option.range.count, to: section))
            }
        }
    }

    private func repeatBars(_ option: ComposeRepeatOption) {
        haptic(.light)
        let count = option.range.count
        editor.perform(
            String(localized: "Repeat bars"),
            toast: count == 1 ? String(localized: "Bar repeated") : String(localized: "\(count) bars repeated")
        ) {
            ComposeChordOps.repeatBars(in: section, range: option.range, times: 1)
        }
    }

    private func addBar() {
        editor.perform(String(localized: "Add bar")) {
            ComposeChordOps.insertBar(in: section, at: section.bars)
        }
    }

    private func clearChords() {
        haptic(.warning)
        editor.perform(String(localized: "Clear chords"), toast: String(localized: "Chords cleared")) {
            for bar in 0..<max(section.bars, (section.chordEvents.map(\.barIndex).max() ?? 0) + 1) {
                ComposeChordOps.clearBar(in: section, bar: bar, context: editor.modelContext)
            }
        }
    }
}

// MARK: - Repeat options

/// A run of bars at the end of a section that can be played again.
struct ComposeRepeatOption: Identifiable {
    let title: String
    let icon: String
    let range: Range<Int>

    var id: String { "\(range.lowerBound)-\(range.upperBound)" }

    /// The last bar, the last 2 and 4 bars, and the whole section — whichever
    /// the section is long enough for, without repeats.
    static func endings(of section: SectionTemplate) -> [ComposeRepeatOption] {
        let bars = max(1, section.bars)
        var options: [ComposeRepeatOption] = [
            ComposeRepeatOption(title: String(localized: "Last bar"), icon: "repeat.1", range: (bars - 1)..<bars)
        ]
        for length in [2, 4] where bars >= length {
            options.append(ComposeRepeatOption(
                title: String(localized: "Last \(length) bars"),
                icon: "repeat",
                range: (bars - length)..<bars
            ))
        }
        if ![1, 2, 4].contains(bars) {
            options.append(ComposeRepeatOption(
                title: String(localized: "Whole section (\(bars) bars)"),
                icon: "arrow.trianglehead.2.clockwise",
                range: 0..<bars
            ))
        }
        return options
    }
}

// MARK: - Linked takes

/// Recordings linked to a section, as a quiet row of playable takes.
struct ComposeLinkedTakesRow: View {
    let recordings: [Recording]
    @ObservedObject var audioManager: AudioRecordingManager
    let tint: Color
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Button {
                haptic(.selection)
                withAnimation(DesignSystem.Animations.smoothSpring) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "waveform")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.accent)
                    Text("\(recordings.count) linked takes")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(recordings.count) linked takes")
            .accessibilityHint(isExpanded ? "Collapse" : "Expand")

            if isExpanded {
                ScrollView(.horizontal) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        ForEach(recordings) { recording in
                            LinkedRecordingCard(
                                recording: recording,
                                isPlaying: audioManager.currentlyPlayingRecording?.id == recording.id,
                                onPlay: {
                                    haptic(.light)
                                    if audioManager.currentlyPlayingRecording?.id == recording.id {
                                        audioManager.stopPlayback()
                                    } else {
                                        audioManager.playRecording(recording)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Linked recording card

struct LinkedRecordingCard: View {
    let recording: Recording
    let isPlaying: Bool
    let onPlay: () -> Void

    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(isPlaying ? DesignSystem.Colors.primary : DesignSystem.Colors.surfaceSecondary)
                        .frame(width: 32, height: 32)
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(isPlaying ? DesignSystem.Colors.onPrimary : DesignSystem.Colors.textPrimary)
                        .offset(x: isPlaying ? 0 : 1)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(recording.name)
                        .font(DesignSystem.Typography.calloutBold)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Image(systemName: recording.recordingType.icon)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(recording.recordingType.color)
                        Text("\(recording.recordingType.recordDisplayName) · \(ComposeFormat.clock(recording.duration))")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                            .monospacedDigit()
                    }
                }
                .frame(maxWidth: 150, alignment: .leading)
            }
            .padding(.leading, 6)
            .padding(.trailing, DesignSystem.Spacing.sm)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(isPlaying ? DesignSystem.Colors.primaryLight : DesignSystem.Colors.surface)
            )
            .overlay(
                Capsule().stroke(isPlaying ? DesignSystem.Colors.primary.opacity(0.5) : DesignSystem.Colors.border, lineWidth: 1)
            )
        }
        .buttonStyle(AnimatedPressButtonStyle(scale: 0.97))
        .accessibilityLabel("\(recording.name), \(recording.recordingType.recordDisplayName)")
        .accessibilityHint(isPlaying ? "Double-tap to stop" : "Double-tap to play")
    }
}
