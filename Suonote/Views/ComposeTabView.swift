import SwiftUI
import SwiftData

struct ComposeTabView: View {
    @Bindable var project: Project
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedSection: SectionTemplate?
    @State private var showingSectionCreator = false
    @State private var showingChordPalette = false
    @State private var selectedChordSlot: ChordSlot?
    @State private var showingKeyPicker = false
    
    var body: some View {
        VStack(spacing: 0) {
            topControlsBar
            
            Divider().overlay(Color.white.opacity(0.1))
            
            if project.arrangementItems.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        arrangementTimeline
                        
                        if let section = selectedSection {
                            sectionEditor(section)
                        }
                    }
                    .padding(24)
                }
            }
        }
        .sheet(isPresented: $showingSectionCreator) {
            SectionCreatorView(project: project, onSectionCreated: { section in
                selectedSection = section
            })
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingChordPalette) {
            if let slot = selectedChordSlot, let section = selectedSection {
                ChordPaletteSheet(
                    section: section,
                    slot: slot,
                    project: project
                )
                .presentationDetents([.large])
            }
        }
        .sheet(isPresented: $showingKeyPicker) {
            KeyPickerSheet(project: project)
        }
    }
    
    private var topControlsBar: some View {
        HStack(spacing: 12) {
            Button {
                showingKeyPicker = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "music.note")
                        .font(.caption)
                    Text("\(project.keyRoot)\(project.keyMode == .minor ? "m" : "")")
                        .font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.purple.opacity(0.15))
                        .overlay(Capsule().stroke(Color.purple, lineWidth: 1))
                )
                .foregroundStyle(.purple)
            }
            
            HStack(spacing: 6) {
                Image(systemName: "metronome")
                    .font(.caption)
                Text("\(project.timeTop)/\(project.timeBottom)")
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.orange.opacity(0.15))
                    .overlay(Capsule().stroke(Color.orange, lineWidth: 1))
            )
            .foregroundStyle(.orange)
            
            HStack(spacing: 6) {
                Image(systemName: "waveform")
                    .font(.caption)
                Text("\(project.bpm)")
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.cyan.opacity(0.15))
                    .overlay(Capsule().stroke(Color.cyan, lineWidth: 1))
            )
            .foregroundStyle(.cyan)
            
            Spacer()
            
            Button {
                showingSectionCreator = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.2), Color.blue.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "music.note.list")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 8) {
                Text("Start Composing")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                
                Text("Add your first section to build your song")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button {
                showingSectionCreator = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Section")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: Color.purple.opacity(0.4), radius: 10, x: 0, y: 5)
                )
            }
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
    
    private var arrangementTimeline: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Arrangement")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                
                Spacer()
                
                Text("\(project.arrangementItems.count) sections")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(project.arrangementItems.enumerated()), id: \.element.id) { index, item in
                        if let section = item.sectionTemplate {
                            SectionTimelineCard(
                                section: section,
                                index: index,
                                isSelected: selectedSection?.id == section.id,
                                onSelect: {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedSection = section
                                    }
                                },
                                onDelete: {
                                    deleteArrangementItem(item)
                                }
                            )
                        }
                    }
                }
            }
        }
    }
    
    private func sectionEditor(_ section: SectionTemplate) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(section.name)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    
                    Text("\(section.bars) bars × \(project.timeTop)/\(project.timeBottom)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            ChordGridView(
                section: section,
                project: project,
                onChordSlotTap: { slot in
                    selectedChordSlot = slot
                    showingChordPalette = true
                }
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.purple.opacity(0.3), lineWidth: 2)
                )
        )
    }
    
    private func deleteArrangementItem(_ item: ArrangementItem) {
        withAnimation {
            if let index = project.arrangementItems.firstIndex(where: { $0.id == item.id }) {
                project.arrangementItems.remove(at: index)
                
                for (newIndex, remainingItem) in project.arrangementItems.enumerated() {
                    remainingItem.orderIndex = newIndex
                }
                
                if selectedSection?.id == item.sectionTemplate?.id {
                    selectedSection = nil
                }
                
                try? modelContext.save()
            }
        }
    }
}

// MARK: - Supporting Views

struct SectionTimelineCard: View {
    let section: SectionTemplate
    let index: Int
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    @State private var showingDeleteConfirmation = false
    
    private var sectionColor: Color {
        switch section.name.lowercased() {
        case let name where name.contains("verse"): return .cyan
        case let name where name.contains("chorus"): return .purple
        case let name where name.contains("bridge"): return .orange
        case let name where name.contains("intro"): return .green
        case let name where name.contains("outro"): return .blue
        default: return .pink
        }
    }
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(index + 1)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(sectionColor))
                    
                    Spacer()
                    
                    Button(action: { showingDeleteConfirmation = true }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                Text(section.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                Text("\(section.bars) bars")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(width: 120)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? sectionColor.opacity(0.2) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? sectionColor : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .alert("Delete Section?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive, action: onDelete)
        } message: {
            Text("This will remove '\(section.name)' from your arrangement.")
        }
    }
}

struct ChordSlot {
    let barIndex: Int
    let beatOffset: Int
}

struct ChordGridView: View {
    let section: SectionTemplate
    let project: Project
    let onChordSlotTap: (ChordSlot) -> Void
    
    private var beatsPerBar: Int { project.timeTop }
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<section.bars, id: \.self) { barIndex in
                VStack(spacing: 8) {
                    HStack {
                        Text("Bar \(barIndex + 1)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    
                    HStack(spacing: 8) {
                        ForEach(0..<beatsPerBar, id: \.self) { beatOffset in
                            ChordSlotButton(
                                section: section,
                                barIndex: barIndex,
                                beatOffset: beatOffset,
                                beatsPerBar: beatsPerBar,
                                onTap: {
                                    onChordSlotTap(ChordSlot(barIndex: barIndex, beatOffset: beatOffset))
                                }
                            )
                        }
                    }
                }
            }
        }
    }
}

struct ChordSlotButton: View {
    let section: SectionTemplate
    let barIndex: Int
    let beatOffset: Int
    let beatsPerBar: Int
    let onTap: () -> Void
    
    private var chordEvent: ChordEvent? {
        section.chordEvents.first { event in
            event.barIndex == barIndex && event.beatOffset == beatOffset
        }
    }
    
    private var isFirstBeat: Bool {
        beatOffset == 0
    }
    
    private var spanningChord: ChordEvent? {
        section.chordEvents.first { event in
            event.barIndex == barIndex &&
            event.beatOffset < beatOffset &&
            event.beatOffset + event.duration > beatOffset
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(borderColor, lineWidth: borderWidth)
                    )
                
                if let chord = chordEvent {
                    VStack(spacing: 4) {
                        Text(chord.display)
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        if chord.duration > 1 {
                            Text("\(chord.duration)b")
                                .font(.caption2)
                                .foregroundStyle(.purple)
                        }
                    }
                } else if spanningChord != nil {
                    Text("–")
                        .font(.title3)
                        .foregroundStyle(.purple.opacity(0.5))
                } else {
                    Image(systemName: "plus")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 70)
        .contextMenu {
            if chordEvent != nil {
                Button(role: .destructive) {
                    removeChord()
                } label: {
                    Label("Remove Chord", systemImage: "trash")
                }
            }
        }
    }
    
    private var backgroundColor: Color {
        if chordEvent != nil {
            return Color.purple.opacity(0.2)
        } else if spanningChord != nil {
            return Color.purple.opacity(0.1)
        } else {
            return Color.white.opacity(0.03)
        }
    }
    
    private var borderColor: Color {
        if isFirstBeat {
            return Color.orange.opacity(0.5)
        } else {
            return Color.white.opacity(0.1)
        }
    }
    
    private var borderWidth: CGFloat {
        isFirstBeat ? 2 : 1
    }
    
    private func removeChord() {
        if let index = section.chordEvents.firstIndex(where: { 
            $0.barIndex == barIndex && $0.beatOffset == beatOffset 
        }) {
            section.chordEvents.remove(at: index)
        }
    }
}

// MARK: - Section Creator

struct SectionCreatorView: View {
    @Bindable var project: Project
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let onSectionCreated: (SectionTemplate) -> Void
    
    @State private var sectionName = ""
    @State private var bars = 4
    @State private var selectedTemplate: SectionPreset = .verse
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Templates")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(SectionPreset.allCases) { preset in
                            PresetCard(
                                preset: preset,
                                isSelected: selectedTemplate == preset,
                                onSelect: {
                                    selectedTemplate = preset
                                    sectionName = preset.name
                                    bars = preset.defaultBars
                                }
                            )
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Section Name")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        
                        TextField("e.g., Verse 1", text: $sectionName)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            )
                            .foregroundStyle(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Number of Bars")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        
                        Stepper("\(bars) bars", value: $bars, in: 1...32)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            )
                            .foregroundStyle(.white)
                    }
                }
                
                Spacer()
                
                Button {
                    createSection()
                } label: {
                    Text("Create Section")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                }
                .disabled(sectionName.isEmpty)
            }
            .padding(24)
            .navigationTitle("New Section")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            sectionName = selectedTemplate.name
        }
    }
    
    private func createSection() {
        let section = SectionTemplate(name: sectionName, bars: bars)
        let arrangementItem = ArrangementItem(orderIndex: project.arrangementItems.count)
        arrangementItem.sectionTemplate = section
        
        project.arrangementItems.append(arrangementItem)
        
        try? modelContext.save()
        onSectionCreated(section)
        dismiss()
    }
}

enum SectionPreset: String, CaseIterable, Identifiable {
    case intro = "Intro"
    case verse = "Verse"
    case chorus = "Chorus"
    case bridge = "Bridge"
    case solo = "Solo"
    case outro = "Outro"
    
    var id: String { rawValue }
    var name: String { rawValue }
    
    var defaultBars: Int {
        switch self {
        case .intro, .outro: return 2
        case .verse, .chorus, .bridge: return 8
        case .solo: return 16
        }
    }
    
    var icon: String {
        switch self {
        case .intro: return "play.circle"
        case .verse: return "music.note"
        case .chorus: return "music.note.list"
        case .bridge: return "arrow.triangle.branch"
        case .solo: return "guitars"
        case .outro: return "stop.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .intro: return .green
        case .verse: return .cyan
        case .chorus: return .purple
        case .bridge: return .orange
        case .solo: return .pink
        case .outro: return .blue
        }
    }
}

struct PresetCard: View {
    let preset: SectionPreset
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 12) {
                Image(systemName: preset.icon)
                    .font(.title2)
                    .foregroundStyle(preset.color)
                
                Text(preset.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                
                Text("\(preset.defaultBars) bars")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? preset.color.opacity(0.2) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? preset.color : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Chord Palette

struct ChordPaletteSheet: View {
    let section: SectionTemplate
    let slot: ChordSlot
    @Bindable var project: Project
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedRoot = "C"
    @State private var selectedQuality: ChordQuality = .major
    @State private var selectedExtensions: [String] = []
    @State private var duration = 1
    
    private let roots = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    private let commonExtensions = ["7", "9", "11", "13", "sus2", "sus4", "add9"]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text(chordDisplay)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text("Bar \(slot.barIndex + 1) • Beat \(slot.beatOffset + 1)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 20)
                
                ScrollView {
                    VStack(spacing: 24) {
                        rootSelector
                        qualitySelector
                        extensionsSelector
                        durationSelector
                    }
                }
                
                addButton
            }
            .padding(24)
            .navigationTitle("Add Chord")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            selectedRoot = project.keyRoot
        }
    }
    
    private var rootSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Root Note")
                .font(.headline)
                .foregroundStyle(.white)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                ForEach(roots, id: \.self) { root in
                    Button {
                        selectedRoot = root
                    } label: {
                        Text(root)
                            .font(.headline)
                            .foregroundStyle(selectedRoot == root ? .white : .secondary)
                            .frame(height: 44)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedRoot == root ? Color.purple : Color.white.opacity(0.05))
                            )
                    }
                }
            }
        }
    }
    
    private var qualitySelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quality")
                .font(.headline)
                .foregroundStyle(.white)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(ChordQuality.allCases, id: \.self) { quality in
                    Button {
                        selectedQuality = quality
                    } label: {
                        Text(quality.rawValue.isEmpty ? "Major" : quality.rawValue)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selectedQuality == quality ? .white : .secondary)
                            .frame(height: 44)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedQuality == quality ? Color.blue : Color.white.opacity(0.05))
                            )
                    }
                }
            }
        }
    }
    
    private var extensionsSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Extensions")
                .font(.headline)
                .foregroundStyle(.white)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                ForEach(commonExtensions, id: \.self) { ext in
                    Button {
                        if selectedExtensions.contains(ext) {
                            selectedExtensions.removeAll { $0 == ext }
                        } else {
                            selectedExtensions.append(ext)
                        }
                    } label: {
                        Text(ext)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(selectedExtensions.contains(ext) ? .white : .secondary)
                            .frame(height: 40)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(selectedExtensions.contains(ext) ? Color.cyan : Color.white.opacity(0.05))
                            )
                    }
                }
            }
        }
    }
    
    private var durationSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Duration (beats)")
                .font(.headline)
                .foregroundStyle(.white)
            
            Stepper("\(duration) beat\(duration > 1 ? "s" : "")", value: $duration, in: 1...16)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
                .foregroundStyle(.white)
        }
    }
    
    private var addButton: some View {
        Button {
            addChord()
        } label: {
            Text("Add Chord")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
        }
    }
    
    private var chordDisplay: String {
        var display = selectedRoot + selectedQuality.symbol
        if !selectedExtensions.isEmpty {
            display += selectedExtensions.joined()
        }
        return display
    }
    
    private func addChord() {
        section.chordEvents.removeAll { 
            $0.barIndex == slot.barIndex && $0.beatOffset == slot.beatOffset 
        }
        
        let chord = ChordEvent(
            barIndex: slot.barIndex,
            beatOffset: slot.beatOffset,
            duration: duration,
            root: selectedRoot,
            quality: selectedQuality,
            extensions: selectedExtensions
        )
        
        section.chordEvents.append(chord)
        dismiss()
    }
}

// MARK: - Key Picker

struct KeyPickerSheet: View {
    @Bindable var project: Project
    @Environment(\.dismiss) private var dismiss
    
    private let roots = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Root Note")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                        ForEach(roots, id: \.self) { root in
                            Button {
                                project.keyRoot = root
                            } label: {
                                Text(root)
                                    .font(.headline)
                                    .foregroundStyle(project.keyRoot == root ? .white : .secondary)
                                    .frame(height: 50)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(project.keyRoot == root ? Color.purple : Color.white.opacity(0.05))
                                    )
                            }
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Mode")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    HStack(spacing: 12) {
                        Button {
                            project.keyMode = .major
                        } label: {
                            Text("Major")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(project.keyMode == .major ? .white : .secondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(project.keyMode == .major ? Color.blue : Color.white.opacity(0.05))
                                )
                        }
                        
                        Button {
                            project.keyMode = .minor
                        } label: {
                            Text("Minor")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(project.keyMode == .minor ? .white : .secondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(project.keyMode == .minor ? Color.blue : Color.white.opacity(0.05))
                                )
                        }
                    }
                }
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                }
            }
            .padding(24)
            .navigationTitle("Change Key")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }
}
