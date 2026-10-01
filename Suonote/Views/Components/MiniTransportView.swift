import SwiftUI

/// The project's single transport, shown as the TabView bottom accessory on
/// every tab (Liquid Glass is supplied by the accessory itself).
///
/// Expanded: play · section + bar.beat · loop · click (hold for count-in) · stop,
/// with a slim scrubbable progress line. Inline (tab bar minimized): play +
/// section + timecode. The full-screen track editor uses the matching
/// `StudioFloatingTransport`, so the controls read the same everywhere.
struct MiniTransportView: View {
    @Bindable var project: Project
    @EnvironmentObject private var playback: StudioPlaybackEngine
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    @State private var isScrubbing = false
    @State private var scrubBeat: Double = 0

    private var canPlay: Bool { StudioTransportActions.canPlay(project) }

    private var beatsPerBar: Int { max(1, project.timeTop) }

    private var maxBeats: Double {
        Double(max(1, project.studioTotalBars * beatsPerBar))
    }

    private var displayBeat: Double {
        isScrubbing ? scrubBeat : playback.currentBeat
    }

    private var hasStarted: Bool {
        playback.isPlaying || playback.currentBeat > 0
    }

    private var isInline: Bool { placement == .inline }

    private var title: String {
        if playback.isCountingIn { return String(localized: "Count-in…") }
        if hasStarted || isScrubbing,
           let section = project.studioSection(atBar: Int(displayBeat / Double(beatsPerBar))) {
            return section.name
        }
        return project.title
    }

    private var idleSubtitle: String {
        if !project.studioHasSections { return String(localized: "Add sections in Compose") }
        if project.studioTracks.isEmpty { return String(localized: "Add a track in Studio") }
        let count = project.studioTracks.count
        return String(localized: "\(count) tracks · \(project.bpm) BPM")
    }

    var body: some View {
        Group {
            if isInline {
                inlineBody
            } else {
                expandedBody
            }
        }
        .animation(DesignSystem.Animations.quickEase, value: playback.isPlaying)
        .onAppear {
            playback.ensurePlayheadTimer()
        }
    }

    // MARK: Inline (minimized tab bar)

    private var inlineBody: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            StudioPlayButton(
                isPlaying: playback.isPlaying,
                isCountingIn: playback.isCountingIn,
                isEnabled: canPlay,
                size: 28
            ) {
                StudioTransportActions.togglePlay(project: project, playback: playback)
            }
            Text(title)
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 4)
            if hasStarted {
                StudioTimecodeText(
                    beatsPerBar: beatsPerBar,
                    font: DesignSystem.Typography.caption.monospacedDigit(),
                    color: DesignSystem.Colors.textSecondary
                )
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
    }

    // MARK: Expanded

    private var expandedBody: some View {
        VStack(spacing: 2) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                StudioPlayButton(
                    isPlaying: playback.isPlaying,
                    isCountingIn: playback.isCountingIn,
                    isEnabled: canPlay,
                    size: 34
                ) {
                    StudioTransportActions.togglePlay(project: project, playback: playback)
                }

                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)
                    if hasStarted || isScrubbing {
                        HStack(spacing: 4) {
                            Text("Bar")
                                .font(DesignSystem.Typography.caption2)
                                .foregroundStyle(DesignSystem.Colors.textTertiary)
                            if isScrubbing {
                                Text(StudioMusic.timecode(beat: scrubBeat, beatsPerBar: beatsPerBar))
                                    .font(DesignSystem.Typography.caption.monospacedDigit())
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                            } else {
                                StudioTimecodeText(
                                    beatsPerBar: beatsPerBar,
                                    font: DesignSystem.Typography.caption.monospacedDigit(),
                                    color: DesignSystem.Colors.textSecondary
                                )
                            }
                            if playback.isLooping {
                                Image(systemName: "repeat")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(DesignSystem.Colors.primaryDark)
                                    .accessibilityLabel("Looping")
                            }
                        }
                    } else {
                        Text(idleSubtitle)
                            .font(DesignSystem.Typography.caption2)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                StudioLoopButton(size: 32)
                StudioMetronomeButton(project: project, size: 32)
                if hasStarted {
                    StudioStopButton(size: 32)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            if canPlay {
                progressBar
                    .frame(height: 6)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
    }

    private var progressBar: some View {
        TimelineView(.animation(minimumInterval: nil, paused: !playback.isPlaying || isScrubbing)) { _ in
            GeometryReader { geo in
                let width = geo.size.width
                let beat = isScrubbing ? scrubBeat : (playback.isPlaying ? playback.livePositionBeats() : playback.currentBeat)
                let progress = CGFloat(min(1, max(0, beat / maxBeats)))
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(DesignSystem.Colors.textPrimary.opacity(0.1))
                    if playback.isLooping, let end = playback.loopEndBeat {
                        let startX = width * CGFloat(playback.loopStartBeat / maxBeats)
                        let endX = width * CGFloat(min(1, end / maxBeats))
                        Capsule()
                            .fill(DesignSystem.Colors.primary.opacity(0.25))
                            .frame(width: max(2, endX - startX))
                            .offset(x: startX)
                    }
                    Capsule()
                        .fill(DesignSystem.Colors.brand)
                        .frame(width: max(3, width * progress))
                }
                .frame(height: 3)
                .frame(maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle().inset(by: -8))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let x = max(0, min(value.location.x, width))
                            scrubBeat = Double(x / max(width, 1)) * maxBeats
                            isScrubbing = true
                        }
                        .onEnded { _ in
                            if isScrubbing { playback.seek(to: scrubBeat) }
                            isScrubbing = false
                        }
                )
                .accessibilityElement()
                .accessibilityLabel("Song position")
                .accessibilityValue("Bar \(Int(beat / Double(beatsPerBar)) + 1) of \(project.studioTotalBars)")
                .accessibilityAdjustableAction { direction in
                    let step = Double(beatsPerBar)
                    let target = direction == .increment ? playback.currentBeat + step : playback.currentBeat - step
                    playback.seek(to: max(0, min(maxBeats, target)))
                }
            }
        }
    }
}
