import SwiftUI

/// Persistent transport shown as the TabView bottom accessory on every tab.
/// A compact, Studio-styled player (accent play button, current section,
/// bar·beat, metronome, stop and a slim progress bar) so the arrangement can be
/// auditioned and scrubbed from anywhere. This is the single transport for the
/// project — the Studio tab no longer shows a separate in-content player.
struct MiniTransportView: View {
    @Bindable var project: Project
    @EnvironmentObject private var playback: StudioPlaybackEngine
    @State private var isScrubbing = false
    @State private var scrubBeat: Double = 0

    private var hasPlayableTracks: Bool {
        !project.studioTracks.isEmpty
    }

    private var beatsPerBar: Int {
        max(1, project.timeTop)
    }

    private var accentColor: Color {
        project.studioStyle?.accentColor ?? DesignSystem.Colors.primary
    }

    private var totalBars: Int {
        let bars = project.arrangementItems
            .compactMap { $0.sectionTemplate?.bars }
            .reduce(0, +)
        return max(1, bars)
    }

    private var maxBeats: Double {
        Double(max(1, totalBars * beatsPerBar))
    }

    /// Beat used to render the progress bar; reads the live sequencer position
    /// at frame rate while playing.
    private var renderedBeat: Double {
        if isScrubbing { return scrubBeat }
        if playback.isPlaying { return playback.livePositionBeats() }
        return playback.currentBeat
    }

    private var displayBeat: Double {
        isScrubbing ? scrubBeat : playback.currentBeat
    }

    private var currentBarIndex: Int {
        Int(displayBeat / Double(beatsPerBar))
    }

    private var hasStarted: Bool {
        playback.isPlaying || playback.currentBeat > 0
    }

    /// Section label at the playhead, derived from the arrangement order.
    private var currentSectionLabel: String? {
        var startBar = 0
        for item in project.arrangementItems.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            guard let section = item.sectionTemplate else { continue }
            let bars = max(1, section.bars)
            if currentBarIndex >= startBar && currentBarIndex < startBar + bars {
                let override = item.labelOverride
                return override?.isEmpty == false ? override : section.name
            }
            startBar += bars
        }
        return nil
    }

    private var title: String {
        if hasStarted, let section = currentSectionLabel {
            return section
        }
        return project.title
    }

    private var subtitle: String {
        guard hasPlayableTracks else { return "No Studio tracks yet" }
        if hasStarted {
            let bar = max(1, currentBarIndex + 1)
            let beat = max(1, Int(displayBeat.truncatingRemainder(dividingBy: Double(beatsPerBar))) + 1)
            return "Bar \(bar) · Beat \(beat)"
        }
        return "\(project.studioTracks.count) tracks · \(project.bpm) BPM"
    }

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Button {
                    togglePlayback()
                } label: {
                    Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.textWhite)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 30, height: 30)
                        .background(
                            Circle().fill(hasPlayableTracks ? accentColor : Color.secondary)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!hasPlayableTracks)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(DesignSystem.Typography.calloutBold)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(DesignSystem.Typography.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .contentTransition(.numericText())
                }

                Spacer(minLength: DesignSystem.Spacing.xs)

                TransportCircleButton(
                    icon: "metronome.fill",
                    isActive: playback.isMetronomeEnabled,
                    accentColor: accentColor
                ) {
                    playback.isMetronomeEnabled.toggle()
                    haptic(.selection)
                }

                if hasStarted {
                    TransportCircleButton(
                        icon: "stop.fill",
                        isActive: false,
                        accentColor: accentColor
                    ) {
                        playback.stop(resetPosition: true)
                        haptic(.light)
                    }
                }
            }

            if hasPlayableTracks {
                progressBar
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .animation(DesignSystem.Animations.quickEase, value: playback.isPlaying)
        .onAppear {
            playback.ensurePlayheadTimer()
        }
    }

    private var progressBar: some View {
        TimelineView(.animation(minimumInterval: nil, paused: !playback.isPlaying || isScrubbing)) { _ in
            GeometryReader { geo in
                let width = geo.size.width
                let progress = CGFloat(min(1, max(0, renderedBeat / maxBeats)))
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(accentColor.opacity(0.2))
                        .frame(height: 4)
                    Capsule()
                        .fill(accentColor)
                        .frame(width: max(4, width * progress), height: 4)
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle().inset(by: -8))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let x = max(0, min(value.location.x, width))
                            scrubBeat = Double(x / width) * maxBeats
                            isScrubbing = true
                        }
                        .onEnded { _ in
                            if isScrubbing { playback.seek(to: scrubBeat) }
                            isScrubbing = false
                        }
                )
            }
        }
    }

    private func togglePlayback() {
        if playback.isPlaying {
            playback.pause()
        } else {
            playback.playRebuildingIfNeeded(project: project)
        }
        haptic(.light)
    }
}
