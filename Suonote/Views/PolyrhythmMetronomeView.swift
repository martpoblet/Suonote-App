import SwiftUI
import AudioToolbox
import AVFoundation

// MARK: - Polyrhythm Metronome (S2)
// Supports standard and polyrhythmic click patterns (e.g., 3:2, 4:3, 5:4)

struct PolyrhythmPattern: Identifiable, Equatable {
    let id = UUID()
    let label: String
    let numerator: Int    // beats in pattern A
    let denominator: Int  // beats in pattern B (cross-rhythm)
    let description: String
}

struct PolyrhythmMetronomeView: View {
    let bpm: Int
    @State private var isPlaying = false
    @State private var selectedPattern: PolyrhythmPattern = Self.patterns[0]
    @State private var beatA: Int = 0
    @State private var beatB: Int = 0
    @State private var volume: Double = 0.8
    @State private var highlightBeat: Bool = true
    @State private var clickTimer: Timer? = nil
    @State private var clickEngine: PolyrhythmClickEngine? = nil

    static let patterns: [PolyrhythmPattern] = [
        PolyrhythmPattern(label: "Standard", numerator: 1, denominator: 1,
                          description: "Regular click on each beat"),
        PolyrhythmPattern(label: "3:2", numerator: 3, denominator: 2,
                          description: "3 beats against 2 — Hemiola, Bossa Nova feel"),
        PolyrhythmPattern(label: "4:3", numerator: 4, denominator: 3,
                          description: "4 against 3 — Complex jazz/African polyrhythm"),
        PolyrhythmPattern(label: "5:4", numerator: 5, denominator: 4,
                          description: "5 against 4 — Advanced metric modulation"),
        PolyrhythmPattern(label: "6:4", numerator: 6, denominator: 4,
                          description: "6 against 4 — Compound duple vs simple triple"),
        PolyrhythmPattern(label: "2:3", numerator: 2, denominator: 3,
                          description: "2 against 3 — Clave-inspired cross-rhythm"),
    ]

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {

            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Polyrhythm Metronome")
                        .font(DesignSystem.Typography.bodyBold)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Text("\(bpm) BPM · \(selectedPattern.label)")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
                Spacer()
                playButton
            }

            // Pattern selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(Self.patterns) { pattern in
                        Button {
                            if isPlaying { stopMetronome() }
                            selectedPattern = pattern
                        } label: {
                            VStack(spacing: 3) {
                                Text(pattern.label)
                                    .font(DesignSystem.Typography.calloutBold)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                    .fill(selectedPattern.id == pattern.id ?
                                          DesignSystem.Colors.primary : DesignSystem.Colors.surfaceSecondary)
                            )
                            .foregroundStyle(selectedPattern.id == pattern.id ? .white : DesignSystem.Colors.textPrimary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Description
            Text(selectedPattern.description)
                .font(DesignSystem.Typography.callout)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.sm)

            // Beat visualizer
            if selectedPattern.numerator != selectedPattern.denominator {
                beatVisualizer
            } else {
                simpleBeatVisualizer
            }

            // Volume
            HStack {
                Image(systemName: "speaker.fill")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                Slider(value: $volume, in: 0...1)
                    .tint(DesignSystem.Colors.primary)
                Image(systemName: "speaker.wave.3.fill")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                        .stroke(DesignSystem.Colors.border, lineWidth: 1)
                )
        )
        .onDisappear { stopMetronome() }
    }

    // MARK: - Play Button

    private var playButton: some View {
        Button {
            if isPlaying { stopMetronome() } else { startMetronome() }
        } label: {
            ZStack {
                Circle()
                    .fill(isPlaying ? DesignSystem.Colors.error : DesignSystem.Colors.primary)
                    .frame(width: 48, height: 48)
                Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .animatedPress()
    }

    // MARK: - Beat Visualizers

    private var beatVisualizer: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            // Pattern A (numerator)
            HStack(spacing: 6) {
                Text("A")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .frame(width: 16)
                ForEach(0..<selectedPattern.numerator, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(beatA == i && isPlaying ?
                              DesignSystem.Colors.primary : DesignSystem.Colors.border)
                        .frame(height: 24)
                        .animation(.easeOut(duration: 0.05), value: beatA)
                }
            }

            // Pattern B (denominator)
            HStack(spacing: 6) {
                Text("B")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .frame(width: 16)
                ForEach(0..<selectedPattern.denominator, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(beatB == i && isPlaying ?
                              DesignSystem.Colors.accent : DesignSystem.Colors.border)
                        .frame(height: 24)
                        .animation(.easeOut(duration: 0.05), value: beatB)
                }
            }
        }
    }

    private var simpleBeatVisualizer: some View {
        HStack(spacing: 6) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 4)
                    .fill(beatA == i && isPlaying ?
                          DesignSystem.Colors.primary : DesignSystem.Colors.border)
                    .frame(height: 24)
                    .animation(.easeOut(duration: 0.05), value: beatA)
            }
        }
    }

    // MARK: - Metronome Engine

    private func startMetronome() {
        let engine = PolyrhythmClickEngine(
            bpm: bpm,
            numerator: selectedPattern.numerator,
            denominator: selectedPattern.denominator,
            volume: Float(volume)
        )
        clickEngine = engine
        engine.start(onTickA: { tick in
            DispatchQueue.main.async { beatA = tick }
        }, onTickB: { tick in
            DispatchQueue.main.async { beatB = tick }
        })
        isPlaying = true
        HapticFeedback.selection()
    }

    private func stopMetronome() {
        clickEngine?.stop()
        clickEngine = nil
        isPlaying = false
        beatA = 0
        beatB = 0
    }
}

// MARK: - Polyrhythm Click Engine

class PolyrhythmClickEngine {
    private let bpm: Int
    private let numerator: Int
    private let denominator: Int
    private let volume: Float
    private var timer: Timer?
    private var stepCount: Int = 0
    private var totalSteps: Int = 0

    // Callbacks
    private var onTickA: ((Int) -> Void)?
    private var onTickB: ((Int) -> Void)?

    init(bpm: Int, numerator: Int, denominator: Int, volume: Float) {
        self.bpm = bpm
        self.numerator = numerator
        self.denominator = denominator
        self.volume = volume
        // LCM of numerator and denominator gives the cycle length
        self.totalSteps = lcm(numerator, denominator)
    }

    func start(onTickA: @escaping (Int) -> Void, onTickB: @escaping (Int) -> Void) {
        self.onTickA = onTickA
        self.onTickB = onTickB
        stepCount = 0

        // Interval = duration of 1 beat (in seconds) / totalSteps per beat
        let beatInterval = 60.0 / Double(bpm)
        let stepInterval = beatInterval / Double(totalSteps)

        timer = Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let step = stepCount % totalSteps

        // Pattern A fires every (totalSteps / numerator) steps
        if totalSteps > 0 && numerator > 0 && step % (totalSteps / numerator) == 0 {
            let beatIndex = step / (totalSteps / numerator)
            onTickA?(beatIndex % numerator)
            playClick(isAccent: beatIndex == 0, isA: true)
        }

        // Pattern B fires every (totalSteps / denominator) steps
        if totalSteps > 0 && denominator > 0 && step % (totalSteps / denominator) == 0 {
            let beatIndex = step / (totalSteps / denominator)
            onTickB?(beatIndex % denominator)
            // Only play B if it doesn't coincide with A to avoid double-click
            let isCoincident = numerator > 0 && step % (totalSteps / numerator) == 0
            if !isCoincident {
                playClick(isAccent: beatIndex == 0, isA: false)
            }
        }

        stepCount += 1
    }

    private func playClick(isAccent: Bool, isA: Bool) {
        // Use system sound for simple clicks
        let sound: SystemSoundID = isAccent ?
            (isA ? 1104 : 1103) :  // different tones for A vs B
            (isA ? 1057 : 1056)
        AudioServicesPlaySystemSound(sound)
    }

    private func lcm(_ a: Int, _ b: Int) -> Int {
        guard a > 0, b > 0 else { return 1 }
        return a / gcd(a, b) * b
    }

    private func gcd(_ a: Int, _ b: Int) -> Int {
        b == 0 ? a : gcd(b, a % b)
    }
}
