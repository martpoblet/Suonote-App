import SwiftUI
import SwiftData

struct ChordPaletteView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var section: SectionTemplate
    let project: Project
    let barIndex: Int
    let beatOffset: Int
    
    @State private var selectedTab = 0
    @State private var chordPreview = ChordPreviewPlayer()
    
    let notes = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    
    /// Diatonic chords with correct qualities for the project key
    var inKeyChords: [(root: String, quality: ChordQuality)] {
        let normalizedRoot = MusicTheory.normalize(project.keyRoot)
        guard let rootIndex = MusicTheory.noteIndex(normalizedRoot) else { return [] }
        
        let intervals: [Int]
        let qualities: [ChordQuality]
        
        if project.keyMode == .major {
            intervals = [0, 2, 4, 5, 7, 9, 11]
            qualities = [.major, .minor, .minor, .major, .major, .minor, .diminished]
        } else {
            intervals = [0, 2, 3, 5, 7, 8, 10]
            qualities = [.minor, .diminished, .major, .minor, .minor, .major, .major]
        }
        
        return zip(intervals, qualities).map { (interval, quality) in
            let note = notes[(rootIndex + interval) % 12]
            return (root: note, quality: quality)
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
                            ForEach(inKeyChords.indices, id: \.self) { i in
                                let chord = inKeyChords[i]
                                chordButton(root: chord.root, quality: chord.quality)
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
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
                
                ToolbarItem(placement: .destructiveAction) {
                    Button("Clear", role: .destructive) {
                        removeChord()
                        dismiss()
                    }
                    .foregroundStyle(DesignSystem.Colors.error)
                }
            }
        }
    }
    
    private func chordButton(root: String, quality: ChordQuality) -> some View {
        Button {
            chordPreview.playChord(root: root, quality: quality)
            addChord(root: root, quality: quality)
            dismiss()
        } label: {
            Text(root + quality.symbol)
                .font(DesignSystem.Typography.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(DesignSystem.Colors.primary)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .chordAccessibility(root: root, quality: quality)
    }
    
    private func addChord(root: String, quality: ChordQuality) {
        if let existing = section.chordEvents.first(where: { $0.barIndex == barIndex && abs($0.beatOffset - Double(beatOffset)) < 0.01 }) {
            section.chordEvents.removeAll { $0.id == existing.id }
        }
        
        let chord = ChordEvent(
            barIndex: barIndex,
            beatOffset: Double(beatOffset),
            duration: 1.0,
            isRest: false,
            root: root,
            quality: quality
        )
        section.chordEvents.append(chord)
    }
    
    private func removeChord() {
        section.chordEvents.removeAll { $0.barIndex == barIndex && abs($0.beatOffset - Double(beatOffset)) < 0.01 }
    }
}
