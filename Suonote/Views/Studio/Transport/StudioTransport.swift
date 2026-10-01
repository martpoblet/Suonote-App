import SwiftUI
import SwiftData

// MARK: - Studio Transport
/// The one transport vocabulary for the whole project. The same controls power
/// the tab bar accessory (`MiniTransportView`, visible on every tab) and the
/// floating glass bar inside the full-screen track editor, so play / stop /
/// loop / click / count-in always look and behave the same.

/// Shared transport actions so every surface drives the engine identically.
@MainActor
enum StudioTransportActions {
    static func canPlay(_ project: Project) -> Bool {
        project.studioHasSections && !project.studioTracks.isEmpty
    }

    static func togglePlay(project: Project, playback: StudioPlaybackEngine) {
        if playback.isPlaying || playback.isCountingIn {
            playback.pause()
            haptic(.light)
        } else {
            guard canPlay(project) else {
                haptic(.warning)
                return
            }
            // Chords may have changed in Compose since the Studio last looked:
            // rewrite the affected parts first so play always matches the song.
            if let context = project.modelContext,
               StudioSync.syncIfNeeded(project: project, modelContext: context) {
                playback.needsSequenceRebuild = true
            }
            playback.playRebuildingIfNeeded(project: project)
            haptic(.medium)
        }
    }

    static func stop(playback: StudioPlaybackEngine) {
        playback.stop(resetPosition: true)
        haptic(.light)
    }

    static func toggleMetronome(project: Project, playback: StudioPlaybackEngine) {
        // The click track is always in the sequence; toggling just unmutes it,
        // live, without restarting playback.
        playback.isMetronomeEnabled.toggle()
        haptic(.selection)
    }

    static func toggleLoop(playback: StudioPlaybackEngine) {
        if playback.isLooping {
            playback.isLooping = false
            playback.loopStartBeat = 0
            playback.loopEndBeat = nil
        } else {
            playback.isLooping = true
        }
        haptic(.selection)
    }

    /// Loops a single section of the song and moves the playhead into it.
    static func loop(section span: StudioSectionSpan, beatsPerBar: Int, playback: StudioPlaybackEngine) {
        let start = Double(span.startBar * max(1, beatsPerBar))
        let end = Double(span.endBar * max(1, beatsPerBar))
        playback.loopStartBeat = start
        playback.loopEndBeat = end
        playback.isLooping = true
        if playback.currentBeat < start || playback.currentBeat >= end {
            playback.seek(to: start)
        }
        haptic(.selection)
    }
}

// MARK: - Play button

/// Solid teal play/pause disc — the one "alive" control in the transport.
struct StudioPlayButton: View {
    let isPlaying: Bool
    var isCountingIn: Bool = false
    var isEnabled: Bool = true
    var size: CGFloat = 40
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isEnabled ? DesignSystem.Colors.primary : DesignSystem.Colors.surfaceActive)
                if isCountingIn {
                    Circle()
                        .strokeBorder(DesignSystem.Colors.onPrimary.opacity(0.6), lineWidth: 2)
                        .padding(3)
                }
                Image(systemName: isPlaying || isCountingIn ? "pause.fill" : "play.fill")
                    .font(.system(size: size * 0.38, weight: .bold))
                    .foregroundStyle(isEnabled ? DesignSystem.Colors.onPrimary : DesignSystem.Colors.textTertiary)
                    .contentTransition(.symbolEffect(.replace))
                    .offset(x: isPlaying || isCountingIn ? 0 : size * 0.03)
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(isPlaying ? "Pause" : "Play")
    }
}

// MARK: - Live timecode

/// Bar.beat counter that reads the sequencer at frame rate while playing.
struct StudioTimecodeText: View {
    let beatsPerBar: Int
    var font: Font = DesignSystem.Typography.timecode
    var color: Color = DesignSystem.Colors.textPrimary
    @EnvironmentObject private var playback: StudioPlaybackEngine

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !playback.isPlaying)) { _ in
            let beat = playback.isPlaying ? playback.livePositionBeats() : playback.currentBeat
            Text(StudioMusic.timecode(beat: beat, beatsPerBar: beatsPerBar))
                .font(font)
                .foregroundStyle(color)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .accessibilityLabel("Position")
    }
}

// MARK: - Option buttons (loop, click/count-in, stop)

struct StudioLoopButton: View {
    var size: CGFloat = 34
    @EnvironmentObject private var playback: StudioPlaybackEngine

    var body: some View {
        StudioGlassIconButton(
            systemImage: "repeat",
            label: "Loop",
            isOn: playback.isLooping,
            size: size
        ) {
            StudioTransportActions.toggleLoop(playback: playback)
        }
    }
}

/// Tap toggles the click; press-and-hold opens count-in options.
struct StudioMetronomeButton: View {
    @Bindable var project: Project
    var size: CGFloat = 34
    @EnvironmentObject private var playback: StudioPlaybackEngine

    var body: some View {
        Menu {
            Toggle(isOn: Binding(
                get: { playback.isMetronomeEnabled },
                set: { newValue in
                    guard newValue != playback.isMetronomeEnabled else { return }
                    StudioTransportActions.toggleMetronome(project: project, playback: playback)
                }
            )) {
                Label("Click", systemImage: "metronome")
            }
            Picker(selection: $playback.countInBars) {
                Text("No count-in").tag(0)
                Text("1 bar").tag(1)
                Text("2 bars").tag(2)
            } label: {
                Label("Count-in", systemImage: "timer")
            }
            .pickerStyle(.menu)
        } label: {
            Image(systemName: playback.isMetronomeEnabled ? "metronome.fill" : "metronome")
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(playback.isMetronomeEnabled ? DesignSystem.Colors.primaryDark : DesignSystem.Colors.textPrimary)
                .frame(width: size, height: size)
                .background(
                    Circle().fill(playback.isMetronomeEnabled ? DesignSystem.Colors.primaryLight : Color.clear)
                )
                .overlay(alignment: .topTrailing) {
                    if playback.countInBars > 0 {
                        Text("\(playback.countInBars)")
                            .font(DesignSystem.Typography.nano)
                            .foregroundStyle(DesignSystem.Colors.background)
                            .frame(width: 13, height: 13)
                            .background(Circle().fill(DesignSystem.Colors.textPrimary))
                            .offset(x: 2, y: -2)
                    }
                }
                .contentShape(Circle())
        } primaryAction: {
            StudioTransportActions.toggleMetronome(project: project, playback: playback)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .accessibilityLabel("Metronome")
        .accessibilityValue(playback.isMetronomeEnabled ? "On" : "Off")
        .accessibilityHint("Hold for count-in options")
    }
}

struct StudioStopButton: View {
    var size: CGFloat = 34
    @EnvironmentObject private var playback: StudioPlaybackEngine

    var body: some View {
        StudioGlassIconButton(systemImage: "stop.fill", label: "Stop", size: size) {
            StudioTransportActions.stop(playback: playback)
        }
    }
}

// MARK: - Floating transport (editor)

/// Floating Liquid Glass transport used inside full-screen editors, where the
/// tab bar accessory is hidden. Mirrors `MiniTransportView` exactly.
struct StudioFloatingTransport: View {
    @Bindable var project: Project
    @EnvironmentObject private var playback: StudioPlaybackEngine

    private var hasStarted: Bool {
        playback.isPlaying || playback.currentBeat > 0
    }

    private var sectionName: String {
        let beat = playback.currentBeat
        let bar = Int(beat / Double(max(1, project.timeTop)))
        return project.studioSection(atBar: bar)?.name ?? project.title
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            StudioPlayButton(
                isPlaying: playback.isPlaying,
                isCountingIn: playback.isCountingIn,
                isEnabled: StudioTransportActions.canPlay(project),
                size: 44
            ) {
                StudioTransportActions.togglePlay(project: project, playback: playback)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(playback.isCountingIn ? String(localized: "Count-in…") : sectionName)
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    StudioTimecodeText(beatsPerBar: project.timeTop, font: DesignSystem.Typography.caption.monospacedDigit(), color: DesignSystem.Colors.textSecondary)
                    Text("· \(project.bpm) BPM")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            StudioLoopButton()
            StudioMetronomeButton(project: project)
            StudioStopButton()
                .opacity(hasStarted ? 1 : 0.35)
                .disabled(!hasStarted)
        }
        .padding(.leading, 6)
        .padding(.trailing, DesignSystem.Spacing.sm)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .capsule)
        .animation(DesignSystem.Animations.quickEase, value: playback.isPlaying)
    }
}
