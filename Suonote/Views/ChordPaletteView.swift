import SwiftUI
import SwiftData

struct ChordPaletteView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var section: SectionTemplate
    let project: Project
    let barIndex: Int
    let beatOffset: Int
    
    @State private var selectedTab = 0
    
    let notes = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    
    var inKeyChords: [String] {
        let majorScale = ["C", "D", "E", "F", "G", "A", "B"]
        let minorScale = ["A", "B", "C", "D", "E", "F", "G"]
        
        let rootIndex = notes.firstIndex(of: project.keyRoot) ?? 0
        let scale = project.keyMode == .major ? majorScale : minorScale
        
        return scale.enumerated().map { index, _ in
            let noteIndex = (rootIndex + [0, 2, 4, 5, 7, 9, 11][index % 7]) % 12
            return notes[noteIndex]
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Category", selection: $selectedTab) {
                    Text("In Key").tag(0)
                    Text("Other").tag(1)
                    Text("Custom").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()
                
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
                        if selectedTab == 0 {
                            ForEach(inKeyChords, id: \.self) { root in
                                chordButton(root: root, quality: .major)
                                chordButton(root: root, quality: .minor)
                            }
                        } else if selectedTab == 1 {
                            ForEach(notes, id: \.self) { root in
                                chordButton(root: root, quality: .major)
                                chordButton(root: root, quality: .minor)
                                chordButton(root: root, quality: .dominant7)
                            }
                        } else {
                            ForEach(notes, id: \.self) { root in
                                ForEach(ChordQuality.allCases, id: \.self) { quality in
                                    chordButton(root: root, quality: quality)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Select Chord")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .destructiveAction) {
                    Button("Clear", role: .destructive) {
                        removeChord()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func chordButton(root: String, quality: ChordQuality) -> some View {
        Button {
            addChord(root: root, quality: quality)
            dismiss()
        } label: {
            Text(root + quality.symbol)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    private func addChord(root: String, quality: ChordQuality) {
        if let existing = section.chordEvents.first(where: { $0.barIndex == barIndex && abs($0.beatOffset - Double(beatOffset)) < 0.01 }) {
            section.chordEvents.removeAll { $0.id == existing.id }
        }
        
        let chord = ChordEvent(barIndex: barIndex, beatOffset: Double(beatOffset), duration: 1.0, root: root, quality: quality)
        section.chordEvents.append(chord)
    }
    
    private func removeChord() {
        section.chordEvents.removeAll { $0.barIndex == barIndex && abs($0.beatOffset - Double(beatOffset)) < 0.01 }
    }
}
