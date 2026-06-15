import SwiftUI

struct AppLogoView: View {
    var height: CGFloat = 24
    @Environment(\.colorScheme) private var colorScheme
    @State private var cachedUIImage: UIImage?

    private func loadLogo() -> UIImage? {
        let candidates: [URL?] = [
            Bundle.main.url(forResource: "Logo", withExtension: "png", subdirectory: "Logo"),
            Bundle.main.url(forResource: "Logo", withExtension: "png", subdirectory: "Resources/Logo"),
            Bundle.main.url(forResource: "Logo", withExtension: "png")
        ]

        for url in candidates.compactMap({ $0 }) {
            if let image = UIImage(contentsOfFile: url.path) {
                return image
            }
        }
        return nil
    }

    var body: some View {
        Group {
            if let cachedUIImage {
                logoImage(cachedUIImage)
            } else {
                Text("Suonote")
                    .font(DesignSystem.Typography.title3)
                    .foregroundStyle(colorScheme == .dark ? .white : DesignSystem.Colors.primaryDark)
            }
        }
        .frame(height: height)
        .fixedSize(horizontal: true, vertical: false)
        .onAppear {
            if cachedUIImage == nil {
                cachedUIImage = loadLogo()
            }
        }
    }

    @ViewBuilder
    private func logoImage(_ image: UIImage) -> some View {
        if colorScheme == .dark {
            // Flatten the multi-color logo to a single white silhouette in dark mode.
            Image(uiImage: image)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(.white)
        } else {
            Image(uiImage: image)
                .renderingMode(.original)
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        AppLogoView(height: 34)
            .padding()
            .background(DesignSystem.Colors.background)
        AppLogoView(height: 34)
            .padding()
            .background(Color.black)
            .environment(\.colorScheme, .dark)
    }
}
