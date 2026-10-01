import SwiftUI

/// First-launch introduction: Compose → Studio → Record, in three pages.
/// Illustrations are drawn with brand components (no stock symbols) and
/// animate only when Reduce Motion is off.
struct OnboardingView: View {
    let onComplete: () -> Void
    @State private var currentPage = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Page {
        let eyebrow: String
        let title: String
        let body: String
    }

    private let pages: [Page] = [
        Page(eyebrow: String(localized: "Compose"),
             title: String(localized: "Sketch the shape."),
             body: String(localized: "Lay out verses and choruses, then drop in chords bar by bar. Suonote knows your key.")),
        Page(eyebrow: String(localized: "Studio"),
             title: String(localized: "Hear it back."),
             body: String(localized: "Drums, bass and keys play your chords the moment you write them. Pick a style, shape the feel.")),
        Page(eyebrow: String(localized: "Record"),
             title: String(localized: "Catch the take."),
             body: String(localized: "Sing or play over your arrangement. Keep every idea; star the one that lands.")),
    ]

    private var isLast: Bool { currentPage == pages.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, DesignSystem.Spacing.gutter)
                .padding(.top, DesignSystem.Spacing.sm)

            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { index in
                    pageView(index)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            bottomBar
                .padding(.horizontal, DesignSystem.Spacing.gutter)
                .padding(.bottom, DesignSystem.Spacing.md)
        }
        .paperBackground()
        .sensoryFeedback(.selection, trigger: currentPage)
    }

    // MARK: Chrome

    private var topBar: some View {
        HStack {
            AppLogoView(height: 18)
            Spacer()
            if !isLast {
                Button("Skip", action: onComplete)
                    .font(DesignSystem.Typography.buttonSmall)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .buttonStyle(.plain)
                    .padding(.vertical, 8)
                    .accessibilityHint("Skips the introduction")
            }
        }
        .frame(height: 36)
    }

    private var bottomBar: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            HStack(spacing: 6) {
                ForEach(pages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == currentPage ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.borderActive)
                        .frame(width: index == currentPage ? 22 : 6, height: 6)
                }
            }
            .animation(DesignSystem.Animations.quickSpring, value: currentPage)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Page \(currentPage + 1) of \(pages.count)")

            PrimaryButton(isLast ? String(localized: "Start writing") : String(localized: "Continue"), icon: isLast ? "pencil.line" : "arrow.right") {
                if isLast {
                    HapticFeedback.success.trigger()
                    onComplete()
                } else {
                    withAnimation(reduceMotion ? nil : DesignSystem.Animations.smoothSpring) { currentPage += 1 }
                }
            }
        }
    }

    // MARK: Page

    private func pageView(_ index: Int) -> some View {
        let page = pages[index]
        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
            Spacer(minLength: DesignSystem.Spacing.md)

            Group {
                switch index {
                case 0: OnboardingComposeArt(animated: !reduceMotion && currentPage == 0)
                case 1: OnboardingStudioArt(animated: !reduceMotion && currentPage == 1)
                default: OnboardingRecordArt(animated: !reduceMotion && currentPage == 2)
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("\(String(format: "%02d", index + 1)) · \(page.eyebrow)")
                    .eyebrow(color: DesignSystem.Colors.primaryDark)
                Text(page.title)
                    .font(DesignSystem.Typography.display)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(page.body)
                    .font(DesignSystem.Typography.italic)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: DesignSystem.Spacing.md)
        }
        .padding(.horizontal, DesignSystem.Spacing.gutter)
    }
}

// MARK: - Illustrations

/// Arrangement ribbon + a bar of chords, the current chord lit in teal.
private struct OnboardingComposeArt: View {
    let animated: Bool
    private let chords = ["Am", "F", "C", "G"]
    private let demo = LibraryStarter(id: "demo", name: "", detail: "", parts: [
        .init(name: "Intro", bars: 2, color: .sky),
        .init(name: "Verse", bars: 4, color: .sage),
        .init(name: "Chorus", bars: 4, color: .coral),
        .init(name: "Bridge", bars: 2, color: .lavender),
        .init(name: "Chorus", bars: 4, color: .coral),
    ])

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.6)) { context in
            let active = animated ? Int(context.date.timeIntervalSinceReferenceDate / 0.6) % chords.count : 0
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                LibraryArrangementStrip(starter: demo, height: 8)
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Circle().fill(SectionColor.coral.color).frame(width: 8, height: 8)
                    Text("Chorus").font(DesignSystem.Typography.headline)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Spacer()
                    Text("A minor · 92").font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
                HStack(spacing: 8) {
                    ForEach(chords.indices, id: \.self) { index in
                        Text(chords[index])
                            .font(DesignSystem.Typography.chord)
                            .foregroundStyle(index == active ? DesignSystem.Colors.onPrimary : DesignSystem.Colors.textPrimary)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                                    .fill(index == active ? DesignSystem.Colors.primary : DesignSystem.Colors.surfaceSecondary)
                            )
                    }
                }
                .animation(DesignSystem.Animations.quickSpring, value: active)
            }
            .padding(DesignSystem.Spacing.lg)
            .cardStyle()
        }
    }
}

/// Three instrument lanes with a moving teal playhead.
private struct OnboardingStudioArt: View {
    let animated: Bool
    private let lanes: [(String, [ClosedRange<Double>], Color)] = [
        (String(localized: "Drums"), [0...0.06, 0.25...0.31, 0.5...0.56, 0.75...0.81], SectionColor.sand.color),
        (String(localized: "Bass"), [0...0.2, 0.25...0.45, 0.5...0.7, 0.75...0.95], SectionColor.ocean.color),
        (String(localized: "Keys"), [0...0.45, 0.5...0.95], SectionColor.sage.color),
    ]

    var body: some View {
        TimelineView(.animation(paused: !animated)) { context in
            let progress = animated ? (context.date.timeIntervalSinceReferenceDate / 3.2).truncatingRemainder(dividingBy: 1) : 0.38
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                ForEach(lanes.indices, id: \.self) { index in
                    let lane = lanes[index]
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Text(lane.0)
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                            .frame(width: 44, alignment: .leading)
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(DesignSystem.Colors.surfaceSecondary)
                                ForEach(lane.1.indices, id: \.self) { noteIndex in
                                    let note = lane.1[noteIndex]
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(lane.2.opacity(note.contains(progress) ? 1 : 0.55))
                                        .frame(width: proxy.size.width * (note.upperBound - note.lowerBound), height: proxy.size.height - 10)
                                        .offset(x: proxy.size.width * note.lowerBound)
                                }
                            }
                        }
                        .frame(height: 36)
                    }
                }
            }
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    let laneStart: CGFloat = 44 + DesignSystem.Spacing.sm
                    Rectangle()
                        .fill(DesignSystem.Colors.primary)
                        .frame(width: 2)
                        .offset(x: laneStart + (proxy.size.width - laneStart) * progress)
                }
            }
            .padding(DesignSystem.Spacing.lg)
            .cardStyle()
        }
    }
}

/// A recording take: waveform in terracotta with a live REC badge.
private struct OnboardingRecordArt: View {
    let animated: Bool
    private let bars: [CGFloat] = (0..<36).map { index in
        let x = Double(index)
        return CGFloat(0.25 + 0.6 * abs(sin(x * 0.55) * cos(x * 0.21)))
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.12)) { context in
            let tick = animated ? Int(context.date.timeIntervalSinceReferenceDate / 0.12) : 24
            let lit = tick % (bars.count + 8)
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(DesignSystem.Colors.record)
                            .frame(width: 8, height: 8)
                            .opacity(animated && tick % 8 < 4 ? 0.35 : 1)
                        Text("Rec").eyebrow(color: DesignSystem.Colors.record)
                    }
                    Spacer()
                    Text(String(format: "0:%02d", min(lit, bars.count) / 3 + 4))
                        .font(DesignSystem.Typography.timecode)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
                HStack(alignment: .center, spacing: 3) {
                    ForEach(bars.indices, id: \.self) { index in
                        Capsule()
                            .fill(index < lit ? DesignSystem.Colors.accent : DesignSystem.Colors.border)
                            .frame(maxWidth: .infinity)
                            .frame(height: 70 * bars[index])
                    }
                }
                .frame(height: 70)
                HStack {
                    Text("Chorus — take 3")
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Spacer()
                    Image(systemName: "star.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(DesignSystem.Colors.warning)
                }
            }
            .padding(DesignSystem.Spacing.lg)
            .cardStyle()
        }
    }
}

#Preview {
    OnboardingView {}
}
