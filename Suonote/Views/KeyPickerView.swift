import SwiftUI

struct KeyPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var project: Project

    let notes = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    // Aeolian is excluded from the picker — it's identical to Natural Minor.
    // Stored projects with .aeolian are migrated to .minor on appear.
    private let pickerModes = KeyMode.allCases.filter { $0 != .aeolian }

    var body: some View {
        NavigationStack {
            Form {
                Section("Root") {
                    Picker("Key", selection: $project.keyRoot) {
                        ForEach(notes, id: \.self) { note in
                            Text(note).tag(note)
                        }
                    }
                    .pickerStyle(.wheel)
                }

                Section("Mode") {
                    Picker("Mode", selection: $project.keyMode) {
                        ForEach(pickerModes, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .onAppear {
                // Normalize legacy .aeolian -> .minor (identical scales)
                if project.keyMode == .aeolian {
                    project.keyMode = .minor
                }
            }
            .navigationTitle("Select Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(DesignSystem.Colors.primaryDark)
                }
            }
        }
    }
}
