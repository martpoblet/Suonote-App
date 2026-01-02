import SwiftUI

struct KeyPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var project: Project
    
    let notes = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    
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
                        ForEach(KeyMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Select Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
