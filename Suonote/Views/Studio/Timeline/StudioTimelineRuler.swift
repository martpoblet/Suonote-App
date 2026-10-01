import SwiftUI

// MARK: - Section timeline
/// The song laid out as proportional section blocks (names in Erode, colored
/// by section) with a smooth teal playhead read from the sequencer at frame
/// rate. Tap to jump, drag to scrub, press and hold a section to loop it.
struct StudioTimelineRuler: View {
    @Bindable var project: Project
    @EnvironmentObject private var playback: StudioPlaybackEngine

    @State private var isScrubbing = false
    @State private var scrubBeat: Double = 0

    private let blockHeight: CGFloat = 54
    private let blockSpacing: CGFloat = 3

    private var spans: [StudioSectionSpan] { project.studioSectionSpans }
    private var beatsPerBar: Int { max(1, project.timeTop) }
    private var totalBars: Int { max(1, spans.last?.endBar ?? project.studioTotalBars) }
    private var totalBeats: Double { Double(totalBars * beatsPerBar) }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .topLeading) {
                    sectionBlocks(width: width)
                    loopOverlay(width: width)
                    playhead(width: width)
                }
                .frame(width: width, height: blockHeight + 10, alignment: .topLeading)
                .contentShape(Rectangle())
                .onTapGesture(coordinateSpace: .local) { location in
                    let beat = beat(forX: location.x, width: width)
                    playback.seek(to: beat)
                    haptic(.selection)
                }
            }
            .frame(height: blockHeight + 10)

            barTicks
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: Blocks

    private func sectionBlocks(width: CGFloat) -> some View {
        let available = max(0, width - blockSpacing * CGFloat(max(0, spans.count - 1)))
        return HStack(spacing: blockSpacing) {
            ForEach(spans) { span in
                let blockWidth = max(6, available * CGFloat(span.bars) / CGFloat(totalBars))
                sectionBlock(span, width: blockWidth)
            }
        }
        .padding(.top, 5)
    }

    private func sectionBlock(_ span: StudioSectionSpan, width: CGFloat) -> some View {
        let isCurrent = currentBar >= span.startBar && currentBar < span.endBar && (playback.isPlaying || playback.currentBeat > 0)
        let isLoopedSection = playback.isLooping
            && playback.loopEndBeat != nil
            && Int(playback.loopStartBeat) == span.startBar * beatsPerBar
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(span.color.opacity(isCurrent ? 0.26 : 0.14))
            Rectangle()
                .fill(span.color)
                .frame(width: 2.5)
                .clipShape(RoundedRectangle(cornerRadius: 1.25))
                .padding(.vertical, 6)
                .padding(.leading, 4)
            if width > 20 {
                VStack(alignment: .leading, spacing: 1) {
                    SectionNameLabel(name: span.name)
                    ViewThatFits(in: .horizontal) {
                        Text("\(span.bars) bars").fixedSize()
                        Text("\(span.bars)").fixedSize()
                    }
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
                .padding(.leading, 12)
                .padding(.trailing, 4)
                .padding(.top, 7)
            }
        }
        .frame(width: width, height: blockHeight)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isLoopedSection ? DesignSystem.Colors.primary : Color.clear, lineWidth: 1.5)
        )
        .contextMenu {
            Button {
                playback.seek(to: Double(span.startBar * beatsPerBar))
            } label: {
                Label("Jump to \(span.name)", systemImage: "arrow.right.to.line")
            }
            Button {
                StudioTransportActions.loop(section: span, beatsPerBar: beatsPerBar, playback: playback)
            } label: {
                Label("Loop \(span.name)", systemImage: "repeat")
            }
            if playback.isLooping {
                Button {
                    StudioTransportActions.toggleLoop(playback: playback)
                } label: {
                    Label("Stop looping", systemImage: "repeat.1")
                }
            }
        } preview: {
            VStack(alignment: .leading, spacing: 4) {
                Text(span.name)
                    .font(DesignSystem.Typography.title3)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Text("Bars \(span.startBar + 1)–\(span.endBar)")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.surface)
        }
        .accessibilityElement()
        .accessibilityLabel("\(span.name), \(span.bars) bars")
        .accessibilityHint("Hold to loop this section")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            playback.seek(to: Double(span.startBar * beatsPerBar))
        }
    }

    // MARK: Loop

    @ViewBuilder
    private func loopOverlay(width: CGFloat) -> some View {
        if playback.isLooping {
            let start = playback.loopStartBeat
            let end = playback.loopEndBeat ?? totalBeats
            let startX = width * CGFloat(start / totalBeats)
            let endX = width * CGFloat(min(1, end / totalBeats))
            Capsule()
                .fill(DesignSystem.Colors.primary)
                .frame(width: max(4, endX - startX), height: 3)
                .offset(x: startX, y: 0)
                .accessibilityHidden(true)
        }
    }

    // MARK: Playhead

    private func playhead(width: CGFloat) -> some View {
        TimelineView(.animation(minimumInterval: nil, paused: !playback.isPlaying || isScrubbing)) { _ in
            let beat = isScrubbing ? scrubBeat : (playback.isPlaying ? playback.livePositionBeats() : playback.currentBeat)
            let x = min(max(0, width * CGFloat(beat / totalBeats)), max(0, width - 2))
            let visible = isScrubbing || playback.isPlaying || playback.currentBeat > 0
            ZStack(alignment: .top) {
                Rectangle()
                    .fill(DesignSystem.Colors.primaryDark)
                    .frame(width: 2, height: blockHeight + 8)
                Circle()
                    .fill(DesignSystem.Colors.primaryDark)
                    .frame(width: 9, height: 9)
                    .offset(y: -3)
            }
            .offset(x: x - 1)
            .opacity(visible ? 1 : 0)
            .allowsHitTesting(false)
        }
        .accessibilityHidden(true)
    }

    // MARK: Ticks

    private var barTicks: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let step = tickStep(for: width)
            ZStack(alignment: .topLeading) {
                ForEach(Array(stride(from: 0, to: totalBars, by: step)), id: \.self) { bar in
                    Text("\(bar + 1)")
                        .font(DesignSystem.Typography.caption2.monospacedDigit())
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .fixedSize()
                        .offset(x: width * CGFloat(bar) / CGFloat(totalBars))
                }
            }
        }
        .frame(height: 14)
        .accessibilityHidden(true)
    }

    private func tickStep(for width: CGFloat) -> Int {
        let perBar = width / CGFloat(totalBars)
        for step in [1, 2, 4, 8, 16, 32] where perBar * CGFloat(step) >= 26 {
            return step
        }
        return 64
    }

    // MARK: Gestures

    private var currentBar: Int {
        Int((isScrubbing ? scrubBeat : playback.currentBeat) / Double(beatsPerBar))
    }

    private func beat(forX x: CGFloat, width: CGFloat) -> Double {
        let ratio = Double(min(max(0, x), width) / max(width, 1))
        // Snap taps to the start of the bar — musicians think in bars.
        let raw = ratio * totalBeats
        let bar = floor(raw / Double(beatsPerBar))
        return min(totalBeats, max(0, bar * Double(beatsPerBar)))
    }
}
