import SwiftUI

extension View {
    func studioModalStyle() -> some View {
        self
            .toolbarBackground(DesignSystem.Colors.backgroundSecondary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .presentationBackground(DesignSystem.Colors.backgroundSecondary)
    }
}
