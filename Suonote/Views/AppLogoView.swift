import SwiftUI

// MARK: - Logo shapes (exact brand geometry)

/// One of the three teal waves of the original Suonote mark.
struct SuonoteLogoWave: Shape {
    let index: Int
    func path(in rect: CGRect) -> Path {
        SuonoteLogoGeometry.wave(index, in: rect)
    }
}

/// One letter of the original "Suonote" wordmark.
struct SuonoteLogoLetter: Shape {
    let index: Int
    func path(in rect: CGRect) -> Path {
        SuonoteLogoGeometry.letter(index, in: rect)
    }
}

/// The original Suonote lockup (waves + wordmark), drawn from the brand SVG.
///
/// `progress` drives the signature animation (0 → hidden, 1 → complete):
/// each wave sweeps in from the left, staggered top to bottom, then the
/// letters rise into place one after another. Static logos just use 1.
struct SuonoteLogo: View {
    var height: CGFloat = 24
    var progress: CGFloat = 1
    /// Wordmark ink; teal waves always stay brand color.
    var ink: Color = DesignSystem.Colors.textPrimary

    private var width: CGFloat {
        height * SuonoteLogoGeometry.size.width / SuonoteLogoGeometry.size.height
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<SuonoteLogoGeometry.waveCount, id: \.self) { index in
                SuonoteLogoWave(index: index)
                    .fill(DesignSystem.Colors.brand)
                    .mask(alignment: .leading) {
                        Rectangle()
                            .frame(width: width * waveReveal(index))
                    }
            }
            ForEach(0..<SuonoteLogoGeometry.letterCount, id: \.self) { index in
                let amount = letterReveal(index)
                SuonoteLogoLetter(index: index)
                    .fill(ink)
                    .opacity(Double(amount))
                    .offset(y: (1 - amount) * height * 0.28)
            }
        }
        .frame(width: width, height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Suonote")
    }

    // The mark only spans the left ~20% of the lockup, so a wave's mask
    // sweeps across that width.
    private func waveReveal(_ index: Int) -> CGFloat {
        let markFraction = SuonoteLogoGeometry.markWidth / SuonoteLogoGeometry.size.width
        let local = stagger(progress, start: CGFloat(index) * 0.1, length: 0.45)
        // Fully revealed → open the mask past the whole lockup.
        return local >= 1 ? 1 : local * markFraction * 1.04
    }

    private func letterReveal(_ index: Int) -> CGFloat {
        let local = stagger(progress, start: 0.42 + CGFloat(index) * 0.055, length: 0.3)
        // Ease-out so letters settle softly.
        return 1 - (1 - local) * (1 - local)
    }

    private func stagger(_ t: CGFloat, start: CGFloat, length: CGFloat) -> CGFloat {
        min(1, max(0, (t - start) / length))
    }
}

/// Animatable wrapper so a single `progress` value can be animated with
/// any SwiftUI animation.
struct AnimatedSuonoteLogo: View, Animatable {
    var height: CGFloat
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        SuonoteLogo(height: height, progress: progress)
    }
}

/// The Suonote logo as used across the app (static).
struct AppLogoView: View {
    var height: CGFloat = 24

    var body: some View {
        SuonoteLogo(height: height)
            .fixedSize()
    }
}

#Preview {
    VStack(spacing: 24) {
        AppLogoView(height: 34)
            .padding()
            .background(DesignSystem.Colors.background)
        AppLogoView(height: 34)
            .padding()
            .background(DesignSystem.Colors.background)
            .environment(\.colorScheme, .dark)
    }
}
