import SwiftUI
import Foundation
import Combine

final class TempoPreviewer: ObservableObject {
    @Published private(set) var isPlaying = false

    private var timer: Timer?
    private var beatIndex = 0
    private var bpm: Int = 120
    private var timeSignature: TimeSignaturePreset = .fourFour

    func toggle(bpm: Int, timeSignature: TimeSignaturePreset) {
        if isPlaying {
            stop()
        } else {
            start(bpm: bpm, timeSignature: timeSignature)
        }
    }

    func start(bpm: Int, timeSignature: TimeSignaturePreset) {
        stop()
        self.bpm = max(1, bpm)
        self.timeSignature = timeSignature
        beatIndex = 0
        isPlaying = true
        scheduleTimer()
    }

    func refreshIfPlaying(bpm: Int, timeSignature: TimeSignaturePreset) {
        guard isPlaying else { return }
        start(bpm: bpm, timeSignature: timeSignature)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        beatIndex = 0
        isPlaying = false
    }

    private func scheduleTimer() {
        let interval = timeSignature.secondsPerTempoBeat(bpm: bpm)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.handleTick()
        }
    }

    private func handleTick() {
        let isAccent = beatIndex % max(1, timeSignature.tempoBeatsPerBar) == 0
        MetronomeClickPlayer.shared.play(accent: isAccent)
        beatIndex += 1
    }

    deinit {
        stop()
    }
}

struct TempoPreviewButton: View {
    @ObservedObject var previewer: TempoPreviewer
    let bpm: Int
    let timeTop: Int
    let timeBottom: Int
    let tint: Color
    var label: String = "Preview Tempo"

    private var timeSignature: TimeSignaturePreset {
        TimeSignaturePreset.from(top: timeTop, bottom: timeBottom)
    }

    var body: some View {
        Button {
            previewer.toggle(bpm: bpm, timeSignature: timeSignature)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: previewer.isPlaying ? "stop.fill" : "play.fill")
                Text(previewer.isPlaying ? "Stop" : label)
            }
            .font(DesignSystem.Typography.caption)
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(tint.opacity(previewer.isPlaying ? 0.9 : 0.35))
            )
            .overlay(
                Capsule()
                    .stroke(tint, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onChange(of: bpm) { _, _ in
            previewer.refreshIfPlaying(bpm: bpm, timeSignature: timeSignature)
        }
        .onChange(of: timeTop) { _, _ in
            previewer.refreshIfPlaying(bpm: bpm, timeSignature: timeSignature)
        }
        .onChange(of: timeBottom) { _, _ in
            previewer.refreshIfPlaying(bpm: bpm, timeSignature: timeSignature)
        }
        .onDisappear {
            previewer.stop()
        }
    }
}
