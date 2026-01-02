import SwiftUI
import SwiftData

struct ComposeTabView: View {
    @Bindable var project: Project
    @State private var selectedArrangementItem: ArrangementItem?
    @State private var showingKeyPicker = false
    @State private var showingExportSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            globalHeaderView
                .padding()
                .background(Color(uiColor: .secondarySystemBackground))
            
            Divider()
            
            VStack(spacing: 16) {
                arrangementBlockView
                    .frame(maxHeight: .infinity)
                
                Divider()
                
                if let selected = selectedArrangementItem {
                    sectionEditorView(for: selected)
                } else {
                    Text("Select a section to edit")
                        .foregroundStyle(.secondary)
                        .frame(maxHeight: .infinity)
                }
            }
            .padding()
        }
    }
    
    private var globalHeaderView: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    showingKeyPicker = true
                } label: {
                    Label("\(project.keyRoot) \(project.keyMode.rawValue)", systemImage: "music.note")
                        .font(.subheadline)
                }
                
                Stepper("BPM: \(project.bpm)", value: $project.bpm, in: 40...240)
                    .font(.subheadline)
            }
            
            HStack {
                Picker("Time Signature", selection: $project.timeTop) {
                    Text("3/4").tag(3)
                    Text("4/4").tag(4)
                    Text("5/4").tag(5)
                    Text("6/8").tag(6)
                }
                .pickerStyle(.segmented)
                
                Spacer()
                
                Button {
                    // Play/Stop placeholder
                } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.title)
                }
                
                Button {
                    // Metronome toggle placeholder
                } label: {
                    Image(systemName: "metronome")
                        .font(.title3)
                }
                
                Button {
                    showingExportSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                }
            }
        }
        .sheet(isPresented: $showingKeyPicker) {
            KeyPickerView(project: project)
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportView(project: project)
        }
    }
    
    private var arrangementBlockView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Arrangement")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    addNewSection()
                } label: {
                    Label("Add Section", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                }
            }
            
            if project.arrangementItems.isEmpty {
                Text("No sections yet. Add a section to begin.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(project.arrangementItems.sorted(by: { $0.orderIndex < $1.orderIndex })) { item in
                            ArrangementItemCard(
                                item: item,
                                isSelected: selectedArrangementItem?.id == item.id
                            ) {
                                selectedArrangementItem = item
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func sectionEditorView(for item: ArrangementItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let section = item.sectionTemplate {
                Text("Edit Section: \(section.name)")
                    .font(.headline)
                
                TextField("Section Name", text: Binding(
                    get: { section.name },
                    set: { section.name = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                
                Stepper("Bars: \(section.barsCount)", value: Binding(
                    get: { section.barsCount },
                    set: { section.barsCount = $0 }
                ), in: 1...32)
                
                Picker("Pattern", selection: Binding(
                    get: { section.patternPreset },
                    set: { section.patternPreset = $0 }
                )) {
                    ForEach(PatternPreset.allCases, id: \.self) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
                .pickerStyle(.segmented)
                
                ChordGridView(section: section, project: project)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
    
    private func addNewSection() {
        let section = SectionTemplate(name: "Section \(project.sectionTemplates.count + 1)")
        section.project = project
        project.sectionTemplates.append(section)
        
        let item = ArrangementItem(orderIndex: project.arrangementItems.count)
        item.sectionTemplate = section
        item.project = project
        project.arrangementItems.append(item)
        
        selectedArrangementItem = item
    }
}

struct ArrangementItemCard: View {
    let item: ArrangementItem
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading) {
                    Text(item.sectionTemplate?.name ?? "Unknown")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("\(item.sectionTemplate?.barsCount ?? 0) bars")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.accentColor)
                }
            }
            .padding()
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color(uiColor: .tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

struct ChordGridView: View {
    @Bindable var section: SectionTemplate
    let project: Project
    @State private var showingChordPalette = false
    @State private var selectedBarIndex: Int?
    @State private var selectedBeatOffset: Int?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Chords")
                .font(.subheadline)
                .fontWeight(.medium)
            
            VStack(spacing: 4) {
                ForEach(0..<section.barsCount, id: \.self) { barIndex in
                    HStack(spacing: 4) {
                        Text("\(barIndex + 1)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        
                        chordSlot(barIndex: barIndex, beatOffset: 0)
                        chordSlot(barIndex: barIndex, beatOffset: 2)
                    }
                }
            }
        }
        .sheet(isPresented: $showingChordPalette) {
            if let barIndex = selectedBarIndex, let beatOffset = selectedBeatOffset {
                ChordPaletteView(
                    section: section,
                    project: project,
                    barIndex: barIndex,
                    beatOffset: beatOffset
                )
            }
        }
    }
    
    private func chordSlot(barIndex: Int, beatOffset: Int) -> some View {
        Button {
            selectedBarIndex = barIndex
            selectedBeatOffset = beatOffset
            showingChordPalette = true
        } label: {
            Text(chordDisplayText(barIndex: barIndex, beatOffset: beatOffset))
                .font(.caption)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(chordExists(barIndex: barIndex, beatOffset: beatOffset) ? Color.accentColor : Color(uiColor: .quaternarySystemBackground))
                .foregroundStyle(chordExists(barIndex: barIndex, beatOffset: beatOffset) ? .white : .secondary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
    
    private func chordDisplayText(barIndex: Int, beatOffset: Int) -> String {
        if let chord = section.chordEvents.first(where: { $0.barIndex == barIndex && $0.beatOffset == beatOffset }) {
            return chord.display
        }
        return "—"
    }
    
    private func chordExists(barIndex: Int, beatOffset: Int) -> Bool {
        section.chordEvents.contains { $0.barIndex == barIndex && $0.beatOffset == beatOffset }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Project.self, configurations: config)
    let project = Project(title: "Test Project")
    container.mainContext.insert(project)
    
    return NavigationStack {
        ComposeTabView(project: project)
    }
    .modelContainer(container)
}
