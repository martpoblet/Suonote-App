import SwiftUI

struct SplashView: View {
    @State private var scale: CGFloat = 0.9
    @State private var opacity: CGFloat = 0.0

    var body: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()

            AppLogoView(height: 32)
                .scaleEffect(scale)
                .opacity(opacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}

struct SplashContainerView: View {
    @State private var showMain = false

    var body: some View {
        ZStack {
            if showMain {
                NavigationStack {
                    ProjectsListView()
                }
                .transition(.opacity)
            } else {
                SplashView()
                    .transition(.opacity)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                withAnimation(.easeOut(duration: 0.35)) {
                    showMain = true
                }
            }
        }
        .preferredColorScheme(.light)
    }
}

#Preview {
    SplashView()
}
