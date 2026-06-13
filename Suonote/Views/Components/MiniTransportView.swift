import SwiftUI

/// Persistent mini transport shown as the TabView bottom accessory.
/// Lets the user audition the Studio arrangement from any tab.
struct MiniTransportView: View {
    @Bindable var project: Project
    @EnvironmentObject private var playback: StudioPlaybackEngine

    private var hasPlayableTracks: Bool {
        !project.studioTracks.isEmpty
    }

    private var beatsPerBar: Int {
        max(1, project.timeTop)
    }

    private var currentBar: Int {
        Int(playback.currentBeat) / beatsPerBar + 1
    }

    private var currentBeatInBar: Int {
        Int(playback.currentBeat) % beatsPerBar + 1
    }

    /// Section label at the playhead, derived from the arrangement order.
    private var currentSectionLabel: String? {
        let playheadBar = Int(playback.currentBeat) / beatsPerBar
        var startBar = 0
        for item in project.arrangementItems.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            guard let section = item.sectionTemplate else { continue }
            let bars = max(1, section.bars)
            if playheadBar >= startBar && playheadBar < startBar + bars {
                let override = item.labelOverride
                return override?.isEmpty == false ? override : section.name
            }
            startBar += bars
        }
        return nil
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Button {
                togglePlayback()
            } label: {
                Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .disabled(!hasPlayableTracks)

            VStack(alignment: .leading, spacing: 1) {
                Text(project.title)
                    .font(DesignSystem.Typography.calloutBold)
                    .lineLimit(1)
                if let section = currentSectionLabel, playback.isPlaying {
                    Text(section)
                        .font(DesignSystem.Typography.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .transition(.opacity)
                } else {
                    Text(hasPlayableTracks ? "\(project.studioTracks.count) tracks · \(project.bpm) BPM" : "No Studio tracks yet")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: DesignSystem.Spacing.xs)

            Text("\(currentBar).\(currentBeatInBar)")
                .font(.system(.callout, design: .monospaced).weight(.medium))
                .foregroundStyle(playback.isPlaying ? DesignSystem.Colors.primaryDark : .secondary)
                .contentTransition(.numericText())

            if playback.isPlaying || playback.currentBeat > 0 {
                Button {
                    playback.stop(resetPosition: true)
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .animation(DesignSystem.Animations.quickEase, value: playback.isPlaying)
        .onAppear {
            playback.ensurePlayheadTimer()
        }
    }

    private func togglePlayback() {
        if playback.isPlaying {
            playback.pause()
        } else {
            playback.prepare(project: project)
            playback.play()
        }
        haptic(.light)
    }
}
