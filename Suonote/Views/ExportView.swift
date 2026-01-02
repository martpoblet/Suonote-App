import SwiftUI

struct ExportView: View {
    @Environment(\.dismiss) private var dismiss
    let project: Project
    
    var body: some View {
        NavigationStack {
            List {
                Section("Export Options") {
                    Button {
                        exportMIDI()
                    } label: {
                        Label("Export as MIDI", systemImage: "doc.text")
                    }
                    
                    Button {
                        exportText()
                    } label: {
                        Label("Export as Text", systemImage: "doc.plaintext")
                    }
                }
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func exportMIDI() {
        // MIDI export placeholder
        dismiss()
    }
    
    private func exportText() {
        // Text export placeholder
        dismiss()
    }
}
