import SwiftUI
import SwiftData

/// Launch moment: the logo waves draw themselves, the wordmark settles,
/// a one-line tagline in Erode italic. Static under Reduce Motion.
struct SplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var logoProgress: CGFloat = 0
    @State private var taglineVisible = false

    private let logoHeight: CGFloat = 30

    var body: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()

            VStack(spacing: DesignSystem.Spacing.lg) {
                // The original brand lockup: waves sweep in, then the
                // wordmark letters rise into place.
                AnimatedSuonoteLogo(height: logoHeight, progress: logoProgress)

                Text("A notebook for songs.")
                    .font(DesignSystem.Typography.italic)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .opacity(taglineVisible ? 1 : 0)
                    .offset(y: taglineVisible ? 0 : 6)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Suonote. A notebook for songs.")
        }
        .onAppear {
            if reduceMotion {
                logoProgress = 1
                taglineVisible = true
                return
            }
            withAnimation(.timingCurve(0.45, 0, 0.2, 1, duration: 1.25)) { logoProgress = 1 }
            withAnimation(.easeOut(duration: 0.5).delay(1.0)) { taglineVisible = true }
        }
    }
}

/// Root container: splash → onboarding (first launch) → library.
struct SplashContainerView: View {
    @State private var showMain = false
    @State private var settings = AppSettings.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            if !showMain {
                SplashView()
                    .transition(.opacity)
            } else if settings.showOnboarding {
                OnboardingView {
                    withAnimation(DesignSystem.Animations.gentleEase) {
                        settings.completeOnboarding()
                    }
                }
                .transition(.opacity)
            } else {
                NavigationStack {
                    ProjectsListView()
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            // People who already have songs don't need the introduction
            // (it can be replayed from Settings).
            if settings.showOnboarding,
               ((try? modelContext.fetchCount(FetchDescriptor<Project>())) ?? 0) > 0 {
                settings.completeOnboarding()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.6 : 2.0)) {
                withAnimation(.easeOut(duration: 0.4)) {
                    showMain = true
                }
            }
        }
    }
}

#Preview {
    SplashView()
}
