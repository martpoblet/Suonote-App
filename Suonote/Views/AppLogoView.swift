import SwiftUI

struct AppLogoView: View {
    var height: CGFloat = 24

    private var logoImage: Image? {
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
            if let logoImage {
                logoImage
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
    }
}

#Preview {
    AppLogoView(height: 34)
        .padding()
        .background(DesignSystem.Colors.background)
}
