import SwiftUI

struct AppLogoView: View {
    var height: CGFloat = 24
    @State private var cachedImage: Image?

    private func loadLogo() -> Image? {
        let candidates: [URL?] = [
            Bundle.main.url(forResource: "Logo", withExtension: "png", subdirectory: "Logo"),
            Bundle.main.url(forResource: "Logo", withExtension: "png", subdirectory: "Resources/Logo"),
            Bundle.main.url(forResource: "Logo", withExtension: "png")
        ]

        for url in candidates.compactMap({ $0 }) {
            if let image = UIImage(contentsOfFile: url.path) {
                return Image(uiImage: image).renderingMode(.original)
            }
        }
        return nil
    }

    var body: some View {
        Group {
            if let cachedImage {
                cachedImage
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Text("Suonote")
                    .font(DesignSystem.Typography.title3)
                    .foregroundStyle(DesignSystem.Colors.primaryDark)
            }
        }
        .frame(height: height)
        .fixedSize(horizontal: true, vertical: false)
        .onAppear {
            if cachedImage == nil {
                cachedImage = loadLogo()
            }
        }
    }
}

#Preview {
    AppLogoView(height: 34)
        .padding()
        .background(DesignSystem.Colors.background)
}
