import SwiftUI

/// Standalone key picker for a song (root + mode). Changes apply live.
struct KeyPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var project: Project

    var body: some View {
        SheetScaffold(
            title: String(localized: "Key"),
            subtitle: ComposeFormat.keyName(root: project.keyRoot, mode: project.keyMode),
            primaryTitle: String(localized: "Done"),
            primaryAction: { dismiss() }
        ) {
            LibraryKeyPicker(root: $project.keyRoot, mode: $project.keyMode)
        }
        .presentationDetents([.medium, .large])
        .studioModalStyle()
        .onAppear {
            // Normalize legacy .aeolian -> .minor (identical scales)
            if project.keyMode == .aeolian {
                project.keyMode = .minor
            }
        }
    }
}
