import SwiftUI

extension View {
    /// Shared chrome for app sheets. On iOS 26 the system supplies the
    /// glass-edged sheet appearance; we only provide an adaptive background.
    func studioModalStyle() -> some View {
        self
            .presentationBackground(DesignSystem.Colors.background)
    }
}
