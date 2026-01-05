import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Compose Tab View
/// Tab principal de composición que permite:
/// - Crear y organizar secciones musicales (Verse, Chorus, Bridge, etc.)
/// - Agregar acordes en una cuadrícula temporal
/// - Exportar la composición
/// - Cambiar tonalidad del proyecto
struct ComposeTabView: View {
    // MARK: - Properties
    @Bindable var project: Project
    @Environment(\.modelContext) private var modelContext
    
    // Estados de la UI
    @State private var selectedSection: SectionTemplate?
    @State private var showingSectionCreator = false
    @State private var showingChordPalette = false
    @State private var selectedChordSlot: ChordSlot?
    @State private var draggingChord: ChordDragInfo?
    @State private var draggingArrangementItemId: UUID?
    @State private var lastTimelineReorderTargetId: UUID?
    @State private var showingKeyPicker = false
    @State private var showingExport = false
    @State private var showingEditSheet = false
    @State private var editingSection: SectionTemplate?
    @StateObject private var audioManager = AudioRecordingManager()
    
    // View mode: true = all sections, false = single section
    @State private var showAllSections = true
    @State private var expandedRecordingSections: Set<UUID> = []
    
    private func recordingsBySectionId() -> [UUID: [Recording]] {
        var map: [UUID: [Recording]] = [:]
        for recording in project.recordings {
            if let sectionId = recording.linkedSectionId {
                map[sectionId, default: []].append(recording)
            }
        }
        return map
    }
    
    /// Encuentra la sección que corresponde a un chord slot
    private func findSection(for slot: ChordSlot) -> SectionTemplate? {
        // Find the section by the sectionId stored in the slot
        return project.arrangementItems
            .compactMap { $0.sectionTemplate }
            .first { $0.id == slot.sectionId }
    }
    
    // MARK: - Body
    var body: some View {
        let sortedItems = project.arrangementItems.sorted(by: { $0.orderIndex < $1.orderIndex })
        let recordingsBySectionId = recordingsBySectionId()
        
        VStack(spacing: 0) {
            // MARK: Top Controls
            /// Barra superior con controles de exportar, tonalidad, BPM, etc.
            topControlsBar
                .padding(.top, 8)  // Extra padding to prevent overlap with navigation bar
            
            Divider().overlay(Color.white.opacity(0.1))
            
            // MARK: Content Area
            if project.arrangementItems.isEmpty {
                // Estado vacío: sin secciones creadas
                emptyStateView
            } else {
                // Lista de secciones con lazy loading para mejor performance
                ScrollView {
                    LazyVStack(spacing: 24) {
                        // Timeline con todas las secciones del proyecto
                        arrangementTimeline(items: sortedItems, recordingsBySectionId: recordingsBySectionId)
                        
                        // Editor de sección(es)
                        if showAllSections {
                            // Mostrar todas las secciones expandidas con drag & drop
                            ForEach(Array(sortedItems.enumerated()), id: \.element.id) { _, item in
                                if let section = item.sectionTemplate {
                                    sectionEditor(section, recordings: recordingsBySectionId[section.id] ?? [])
                                        .id(section.id)
                                }
                            }
                        } else if let section = selectedSection {
                            // Mostrar solo la sección seleccionada
                            sectionEditor(section, recordings: recordingsBySectionId[section.id] ?? [])
                                .id(section.id)
                        }
                    }
                    .padding(24)
                    .padding(.bottom, 24)
                }
            }
        }
        .onAppear {
            // Pre-selecciona la primera sección automáticamente
            if selectedSection == nil, let firstItem = project.arrangementItems.first {
                selectedSection = firstItem.sectionTemplate
            }
            audioManager.setup(project: project)
        }
        // MARK: Sheets & Modals
        .sheet(isPresented: $showingSectionCreator) {
            SectionCreatorView(project: project, onSectionCreated: { section in
                selectedSection = section
            })
        }
        .sheet(item: $selectedChordSlot) { slot in
            // Find the section that contains this chord slot
            if let sectionForSlot = findSection(for: slot) {
                ChordPaletteSheet(
                    section: sectionForSlot,
                    slot: slot,
                    project: project
                )
            }
        }
        .sheet(isPresented: $showingKeyPicker) {
            KeyPickerSheet(project: project)
        }
        .sheet(isPresented: $showingExport) {
            ExportView(project: project)
        }
        .sheet(isPresented: $showingEditSheet) {
            EditProjectSheet(project: project)
        }
        .sheet(item: $editingSection) { section in
            SectionEditorSheet(section: section)
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
            
            Button {
                // Open edit project sheet focused on time signature
                showingEditSheet = true
            } label: {
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
            }
            
            Button {
                // Open edit project sheet focused on BPM
                showingEditSheet = true
            } label: {
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
            }
            
            Spacer()
            
            Button {
                showingExport = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.1))
                    )
            }
            
            Button {
                showingSectionCreator = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .padding(8)
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
    
    private func arrangementTimeline(
        items: [ArrangementItem],
        recordingsBySectionId: [UUID: [Recording]]
    ) -> some View {
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
                    // "View All" card
                    ViewAllSectionsCard(
                        isSelected: showAllSections,
                        onSelect: {
                            withAnimation(.spring(response: 0.3)) {
                                showAllSections = true
                            }
                        }
                    )
                    
                    // Section cards - draggable
                    ForEach(Array(items.enumerated()), id: \.element.id) { _, item in
                        if let section = item.sectionTemplate {
                            SectionTimelineCard(
                                section: section,
                                index: item.orderIndex,
                                isSelected: !showAllSections && selectedSection?.id == section.id,
                                onSelect: {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedSection = section
                                        showAllSections = false
                                    }
                                },
                                onDelete: {
                                    deleteArrangementItem(item)
                                },
                                linkedRecordingsCount: recordingsBySectionId[section.id]?.count ?? 0
                            )
                            .onDrag {
                                draggingArrangementItemId = item.id
                                return NSItemProvider(object: item.id.uuidString as NSString)
                            }
                            .onDrop(of: [UTType.text], delegate: arrangementDropDelegate(for: item))
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func handleArrangementDrop(
        _ providers: [NSItemProvider],
        targetItem: ArrangementItem
    ) -> Bool {
        let handled = loadArrangementItemId(from: providers) { sourceId in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                moveArrangementItem(sourceId: sourceId, targetId: targetItem.id)
            }
            draggingArrangementItemId = nil
            lastTimelineReorderTargetId = nil
        }
        return handled
    }

    private func handleArrangementHover(targetItem: ArrangementItem) {
        guard let sourceId = draggingArrangementItemId,
              sourceId != targetItem.id else {
            return
        }

        if lastTimelineReorderTargetId == targetItem.id {
            return
        }
        lastTimelineReorderTargetId = targetItem.id

        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            moveArrangementItem(sourceId: sourceId, targetId: targetItem.id, shouldSave: false)
        }
    }

    private func arrangementDropDelegate(for item: ArrangementItem) -> ArrangementDropDelegate {
        ArrangementDropDelegate(
            targetItem: item,
            onItemHovered: { target in
                handleArrangementHover(targetItem: target)
            },
            onDrop: { target, providers in
                handleArrangementDrop(providers, targetItem: target)
            },
            onExit: { lastTimelineReorderTargetId = nil }
        )
    }

    private func loadArrangementItemId(
        from providers: [NSItemProvider],
        perform: @escaping (UUID) -> Void
    ) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else {
            return false
        }

        provider.loadObject(ofClass: NSString.self) { object, _ in
            let stringValue: String?
            if let value = object as? String {
                stringValue = value
            } else if let value = object as? NSString {
                stringValue = value as String
            } else {
                stringValue = nil
            }

            guard let stringValue,
                  let id = UUID(uuidString: stringValue) else {
                return
            }

            DispatchQueue.main.async {
                perform(id)
            }
        }

        return true
    }

    private func moveArrangementItem(sourceId: UUID, targetId: UUID, shouldSave: Bool = true) {
        guard sourceId != targetId else { return }

        var ordered = project.arrangementItems.sorted { $0.orderIndex < $1.orderIndex }
        guard let sourceIndex = ordered.firstIndex(where: { $0.id == sourceId }),
              let targetIndex = ordered.firstIndex(where: { $0.id == targetId }) else {
            return
        }

        let movedItem = ordered.remove(at: sourceIndex)
        let destinationIndex = min(targetIndex, ordered.count)
        ordered.insert(movedItem, at: destinationIndex)

        for (newIndex, item) in ordered.enumerated() {
            item.orderIndex = newIndex
        }

        project.arrangementItems = ordered
        if shouldSave {
            try? modelContext.save()
        }
    }
    
    private func sectionEditor(_ section: SectionTemplate, recordings: [Recording]) -> some View {
        let sectionColor = section.color
        
        return VStack(alignment: .leading, spacing: 20) {
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
                
                Button {
                    editingSection = section
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title2)
                        .foregroundStyle(sectionColor)
                }
            }
            
            // Linked recordings section (collapsible)
            if !recordings.isEmpty {
                linkedRecordingsSection(recordings: recordings, section: section)
            }
            
            ChordGridView(
                section: section,
                project: project,
                selectedChordSlot: $selectedChordSlot,
                draggingChord: $draggingChord
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(sectionColor.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(sectionColor.opacity(0.3), lineWidth: 2)
                )
        )
    }
    
    private func linkedRecordingsSection(recordings: [Recording], section: SectionTemplate) -> some View {
        let isExpanded = expandedRecordingSections.contains(section.id)
        
        return VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    if isExpanded {
                        expandedRecordingSections.remove(section.id)
                    } else {
                        expandedRecordingSections.insert(section.id)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "waveform.badge.mic")
                        .font(.caption)
                        .foregroundStyle(.purple)
                    
                    Text("Linked Recordings (\(recordings.count))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(recordings) { recording in
                            LinkedRecordingCard(
                                recording: recording,
                                isPlaying: audioManager.currentlyPlayingRecording?.id == recording.id,
                                onPlay: {
                                    if audioManager.currentlyPlayingRecording?.id == recording.id {
                                        audioManager.stopPlayback()
                                    } else {
                                        audioManager.playRecording(recording)
                                    }
                                }
                            )
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.purple.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.purple.opacity(0.2), lineWidth: 1)
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
    
    // Add this to get recording count
    var linkedRecordingsCount: Int = 0
    
    private var sectionColor: Color {
        section.color
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
                
                HStack(spacing: 4) {
                    Text("\(section.bars) bars")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    if linkedRecordingsCount > 0 {
                        Text("•")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 2) {
                            Image(systemName: "waveform")
                                .font(.caption2)
                            Text("\(linkedRecordingsCount)")
                                .font(.caption2.weight(.medium))
                        }
                        .foregroundStyle(.purple)
                    }
                }
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

struct ArrangementDropDelegate: DropDelegate {
    let targetItem: ArrangementItem
    let onItemHovered: (ArrangementItem) -> Void
    let onDrop: (ArrangementItem, [NSItemProvider]) -> Bool
    let onExit: () -> Void

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.text])
    }

    func dropEntered(info: DropInfo) {
        onItemHovered(targetItem)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        onExit()
    }

    func performDrop(info: DropInfo) -> Bool {
        onDrop(targetItem, info.itemProviders(for: [UTType.text]))
    }
}

struct ChordSlotDropDelegate: DropDelegate {
    let targetChord: ChordEvent
    let onItemHovered: (ChordEvent) -> Void
    let onDrop: (ChordEvent, [NSItemProvider]) -> Bool
    let onExit: () -> Void

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.text])
    }

    func dropEntered(info: DropInfo) {
        onItemHovered(targetChord)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        onExit()
    }

    func performDrop(info: DropInfo) -> Bool {
        onDrop(targetChord, info.itemProviders(for: [UTType.text]))
    }
}

struct BarSlot: Identifiable {
    let id: String
    let beatOffset: Double
    let duration: Double
    let chord: ChordEvent?
}

struct ChordSlot: Identifiable {
    let id = UUID()
    let barIndex: Int
    let beatOffset: Double  // Changed to Double to support half-beats
    let isHalf: Bool  // Indicates if this is a half-beat slot
    let sectionId: UUID  // Track which section this slot belongs to
}

struct ChordDragInfo: Equatable {
    let sourceSectionId: UUID
    let chordId: UUID
    let duration: Double
}

struct ChordGridView: View {
    let section: SectionTemplate
    let project: Project
    @Binding var selectedChordSlot: ChordSlot?
    @Binding var draggingChord: ChordDragInfo?
    
    private var beatsPerBar: Int { project.timeTop }
    private let barRowHeight: CGFloat = 104
    private let barRowSpacing: CGFloat = 12
    
    private var barsListHeight: CGFloat {
        let count = CGFloat(section.bars)
        guard count > 0 else { return 0 }
        return (count * barRowHeight) + (max(0, count - 1) * barRowSpacing)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Show only the bars defined in section.bars
            LazyVStack(spacing: barRowSpacing) {
                ForEach(0..<section.bars, id: \.self) { barIndex in
                    BarRow(
                        section: section,
                        project: project,
                        barIndex: barIndex,
                        beatsPerBar: beatsPerBar,
                        selectedChordSlot: $selectedChordSlot,
                        draggingChord: $draggingChord
                    )
                    .frame(height: barRowHeight)
                }
            }
            .frame(height: barsListHeight)
            
            // Add Bar button
            Button {
                section.bars += 1
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                    Text("Add Bar")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(section.color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(section.color.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                                .foregroundStyle(section.color.opacity(0.5))
                        )
                )
            }
        }
    }
}

struct SwipeActionItem: Identifiable {
    let id = UUID()
    let systemImage: String
    let tint: Color
    let role: ButtonRole?
    let action: () -> Void
}

struct SwipeActionRow<Content: View>: View {
    let actions: [SwipeActionItem]
    let content: Content
    
    private let buttonSize: CGFloat = 40
    private let buttonSpacing: CGFloat = 12
    private let actionGap: CGFloat = 24
    @State private var baseOffset: CGFloat = 0
    @State private var dragTranslation: CGFloat = 0
    
    init(actions: [SwipeActionItem], @ViewBuilder content: () -> Content) {
        self.actions = actions
        self.content = content()
    }
    
    private var actionsWidth: CGFloat {
        guard !actions.isEmpty else { return 0 }
        return (CGFloat(actions.count) * buttonSize) + (CGFloat(max(actions.count - 1, 0)) * buttonSpacing)
    }
    
    private var maxOffset: CGFloat {
        guard !actions.isEmpty else { return 0 }
        return actionsWidth + actionGap
    }
    
    private var dragOffset: CGFloat {
        clampOffset(baseOffset + dragTranslation)
    }
    
    private var revealWidth: CGFloat {
        max(0, -dragOffset)
    }
    
    private var revealProgress: CGFloat {
        guard actionsWidth > 0 else { return 0 }
        return min(1, revealWidth / actionsWidth)
    }
    
    private var effectiveRevealWidth: CGFloat {
        min(revealWidth, actionsWidth)
    }
    
    var body: some View {
        ZStack(alignment: .trailing) {
            actionButtons
            
            content
                .offset(x: dragOffset)
                .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.85), value: baseOffset)
                .gesture(
                    HorizontalPanGesture(
                        onChanged: { translation in
                            dragTranslation = translation
                        },
                        onEnded: { translation in
                            let proposedOffset = clampOffset(baseOffset + translation)
                            if proposedOffset <= -maxOffset * 0.5 {
                                baseOffset = -maxOffset
                            } else {
                                baseOffset = 0
                            }
                            dragTranslation = 0
                        }
                    )
                )
        }
        .clipped()
    }
    
    private var actionButtons: some View {
        HStack(spacing: buttonSpacing) {
            ForEach(Array(actions.enumerated()), id: \.element.id) { index, item in
                let progress = buttonProgress(for: index)
                Button(role: item.role) {
                    item.action()
                    baseOffset = 0
                } label: {
                    Image(systemName: item.systemImage)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: buttonSize, height: buttonSize)
                        .background(Circle().fill(item.tint))
                }
                .scaleEffect(progress, anchor: .trailing)
                .opacity(progress)
                .buttonStyle(.plain)
            }
        }
        .padding(.trailing, 12)
        .frame(width: actionsWidth, alignment: .trailing)
        .opacity(revealProgress == 0 ? 0 : 1)
        .animation(.easeOut(duration: 0.18), value: revealProgress)
    }
    
    private func buttonProgress(for index: Int) -> CGFloat {
        let threshold = CGFloat(index) * (buttonSize + buttonSpacing)
        let raw = (effectiveRevealWidth - threshold) / buttonSize
        return max(0, min(1, raw))
    }
    
    private func clampOffset(_ offset: CGFloat) -> CGFloat {
        max(-maxOffset, min(0, offset))
    }
}

@MainActor
struct HorizontalPanGesture: UIGestureRecognizerRepresentable {
    typealias UIGestureRecognizerType = UIPanGestureRecognizer
    var onChanged: (CGFloat) -> Void
    var onEnded: (CGFloat) -> Void
    
    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let recognizer = UIPanGestureRecognizer()
        recognizer.maximumNumberOfTouches = 1
        return recognizer
    }
    
    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = context.coordinator
    }
    
    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let translation = recognizer.translation(in: recognizer.view).x
        switch recognizer.state {
        case .began, .changed:
            onChanged(translation)
        case .ended, .cancelled, .failed:
            onEnded(translation)
        default:
            break
        }
    }
    
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private let parent: HorizontalPanGesture
        
        init(_ parent: HorizontalPanGesture) {
            self.parent = parent
        }
        
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y) * 1.3
        }
        
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            false
        }
    }
}

// MARK: - Bar Row Component
struct BarRow: View {
    let section: SectionTemplate
    let project: Project
    let barIndex: Int
    let beatsPerBar: Int
    @Binding var selectedChordSlot: ChordSlot?
    @Binding var draggingChord: ChordDragInfo?
    @State private var isBarDropTargeted = false
    @State private var lastChordReorderTargetId: UUID?
    
    private let slotSpacing: CGFloat = 6
    
    var body: some View {
        let slots = slotsForBar(barIndex)
        
        if !slots.isEmpty {
            SwipeActionRow(actions: swipeActions) {
                barContent(slots: slots)
                    .id("bar-\(barIndex)")
            }
        }
    }
    
    private var swipeActions: [SwipeActionItem] {
        var items: [SwipeActionItem] = []
        items.append(
            SwipeActionItem(systemImage: "doc.on.doc.fill", tint: .blue, role: nil) {
                cloneBar()
            }
        )
        
        if section.bars > 1 {
            items.append(
                SwipeActionItem(systemImage: "trash.fill", tint: .red, role: .destructive) {
                    deleteBar()
                }
            )
        }
        
        return items
    }
    
    private func cloneBar() {
        // Clone all chords in this bar to the next bar
        let chordsInBar = section.chordEvents.filter { $0.barIndex == barIndex }
        
        // Add new bar
        section.bars += 1
        let newBarIndex = barIndex + 1
        
        // Shift existing chords after this bar
        for chord in section.chordEvents where chord.barIndex >= newBarIndex {
            chord.barIndex += 1
        }
        
        // Clone chords to new bar
        for chord in chordsInBar {
            let clonedChord = ChordEvent(
                barIndex: newBarIndex,
                beatOffset: chord.beatOffset,
                duration: chord.duration,
                root: chord.root,
                quality: chord.quality,
                extensions: chord.extensions,
                slashRoot: chord.slashRoot
            )
            section.chordEvents.append(clonedChord)
        }
    }
    
    private func deleteBar() {
        guard section.bars > 1 else { return }
        
        // Remove all chords in this bar
        section.chordEvents.removeAll { $0.barIndex == barIndex }
        
        // Shift chords after this bar down
        for chord in section.chordEvents where chord.barIndex > barIndex {
            chord.barIndex -= 1
        }
        
        // Decrease bar count
        section.bars -= 1
    }
    
    private func barContent(
        slots: [BarSlot]
    ) -> some View {
        VStack(spacing: 8) {
            barHeader
            barGrid(slots: slots)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(section.color.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(section.color.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private var barHeader: some View {
        let used = beatsUsedInBar(barIndex)
        return HStack {
            Text("Bar \(barIndex + 1)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            
            Spacer()
            
            if used > 0 {
                Text("\(String(format: "%.1f", used))/\(beatsPerBar) beats")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private func barGrid(
        slots: [BarSlot]
    ) -> some View {
        let hasEmptySlot = slots.contains { $0.chord == nil }
        
        return GeometryReader { geometry in
            let totalSpacing = slotSpacing * CGFloat(max(slots.count - 1, 0))
            let availableWidth = max(0, geometry.size.width - totalSpacing)
            
            HStack(spacing: slotSpacing) {
                ForEach(slots) { slot in
                    slotView(slot: slot, totalWidth: availableWidth)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 50)
        .contentShape(Rectangle())
        .overlay(alignment: .trailing) {
            if isBarDropTargeted && !canDropInBar() && !hasEmptySlot {
                Image(systemName: "xmark.octagon.fill")
                    .font(.title3)
                    .foregroundStyle(.red)
                    .padding(.trailing, 8)
            }
        }
    }
    
    @ViewBuilder
    private func slotView(
        slot: BarSlot,
        totalWidth: CGFloat
    ) -> some View {
        if let chord = slot.chord {
            ChordSlotButton(
                section: section,
                barIndex: barIndex,
                beatOffset: slot.beatOffset,
                isHalf: chord.duration < 1.0,
                selectedSlot: $selectedChordSlot,
                draggingChord: $draggingChord
            )
            .frame(width: widthForDuration(chord.duration, totalWidth: totalWidth))
            .frame(height: 50)
            .contextMenu {
                if canDuplicateChord(chord) {
                    Button {
                        duplicateChord(chord)
                    } label: {
                        Label("Duplicate", systemImage: "doc.on.doc.fill")
                    }
                }
                
                Button(role: .destructive) {
                    deleteChord(chord)
                } label: {
                    Label("Delete", systemImage: "trash.fill")
                }
            }
            .onDrop(of: [UTType.text], delegate: chordSlotDropDelegate(for: chord))
        } else {
            let showBlocked = isBarDropTargeted && !canDropInBar()
            Button {
                selectedChordSlot = ChordSlot(
                    barIndex: barIndex,
                    beatOffset: slot.beatOffset,
                    isHalf: slot.duration < 1.0,
                    sectionId: section.id
                )
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: showBlocked ? "xmark.octagon.fill" : "plus.circle.fill")
                        .font(.title3)
                    Text("Add")
                        .font(.caption2.weight(.medium))
                }
                .foregroundStyle(showBlocked ? .red : section.color)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                        .foregroundStyle(showBlocked ? Color.red.opacity(0.6) : section.color.opacity(0.4))
                )
            }
            .buttonStyle(.plain)
            .frame(width: widthForDuration(slot.duration, totalWidth: totalWidth))
            .onDrop(of: [UTType.text], isTargeted: $isBarDropTargeted) { providers in
                guard canDropInBar() else { return false }
                return handleBarDrop(providers)
            }
        }
    }
    
    private func beatsUsedInBar(_ barIndex: Int) -> Double {
        let chordsInBar = section.chordEvents.filter { $0.barIndex == barIndex }
        guard !chordsInBar.isEmpty else { return 0 }
        let total = chordsInBar.reduce(0.0) { $0 + $1.duration }
        return min(total, Double(beatsPerBar))
    }
    
    private func slotsForBar(
        _ barIndex: Int
    ) -> [BarSlot] {
        var slots: [BarSlot] = []
        let chordsInBar = section.chordEvents
            .filter { $0.barIndex == barIndex }
            .sorted { $0.beatOffset < $1.beatOffset }
        
        for chord in chordsInBar {
            slots.append(
                BarSlot(
                    id: chord.id.uuidString,
                    beatOffset: chord.beatOffset,
                    duration: chord.duration,
                    chord: chord
                )
            )
        }
        
        let currentBeat = chordsInBar.map { $0.beatOffset + $0.duration }.max() ?? 0
        if currentBeat < Double(beatsPerBar) {
            let remaining = Double(beatsPerBar) - currentBeat
            let addDuration = min(1.0, remaining)
            slots.append(
                BarSlot(
                    id: "empty-\(barIndex)-\(currentBeat)",
                    beatOffset: currentBeat,
                    duration: addDuration,
                    chord: nil
                )
            )
        }
        
        return slots
    }
    
    private func widthForDuration(_ duration: Double, totalWidth: CGFloat) -> CGFloat {
        let beatWidth = totalWidth / CGFloat(beatsPerBar)
        return beatWidth * CGFloat(duration)
    }
    
    private func duplicateChord(_ chord: ChordEvent) {
        guard let targetBeat = duplicateTargetBeat(for: chord) else {
            return
        }
        
        let clonedChord = ChordEvent(
            barIndex: barIndex,
            beatOffset: targetBeat,
            duration: chord.duration,
            root: chord.root,
            quality: chord.quality,
            extensions: chord.extensions,
            slashRoot: chord.slashRoot
        )
        clonedChord.sectionTemplate = section
        section.chordEvents.append(clonedChord)
    }
    
    private func deleteChord(_ chord: ChordEvent) {
        if let index = section.chordEvents.firstIndex(where: { $0.id == chord.id }) {
            section.chordEvents.remove(at: index)
            compactBarChords(in: section, barIndex: barIndex)
        }
    }
    
    private func canDuplicateChord(_ chord: ChordEvent) -> Bool {
        duplicateTargetBeat(for: chord) != nil
    }
    
    private func duplicateTargetBeat(for chord: ChordEvent) -> Double? {
        let chordEnd = chord.beatOffset + chord.duration
        let barEnd = Double(beatsPerBar)
        guard chordEnd < barEnd - 0.0001 else { return nil }
        
        return nextAvailableBeat(
            for: chord.duration,
            startingAt: chordEnd,
            excluding: nil
        )
    }
    
    private func canDropInBar() -> Bool {
        guard let dragInfo = draggingChord,
              let sourceSection = sectionById(dragInfo.sourceSectionId),
              let chord = sourceSection.chordEvents.first(where: { $0.id == dragInfo.chordId }) else {
            return true
        }
        
        let excludeChord = sourceSection.id == section.id ? chord : nil
        let targetBeatOffset = nextAvailableBeat(excluding: excludeChord)
        
        return canPlaceChord(
            chord,
            targetBeatOffset: targetBeatOffset,
            excluding: excludeChord
        )
    }
    
    private func handleBarDrop(_ providers: [NSItemProvider]) -> Bool {
        return loadChordPayload(from: providers) { payload in
            guard let sourceSection = sectionById(payload.sourceSectionId),
                  let chord = sourceSection.chordEvents.first(where: { $0.id == payload.chordId }) else {
                return
            }
            
            let excludeChord = sourceSection.id == section.id ? chord : nil
            let targetBeatOffset = nextAvailableBeat(excluding: excludeChord)
            
            moveChord(
                chordId: payload.chordId,
                sourceSectionId: payload.sourceSectionId,
                targetBeatOffset: targetBeatOffset
            )
            draggingChord = nil
        }
    }

    private func handleChordSlotHover(targetChord: ChordEvent) {
        guard let dragInfo = draggingChord,
              dragInfo.chordId != targetChord.id,
              let sourceSection = sectionById(dragInfo.sourceSectionId),
              let sourceChord = sourceSection.chordEvents.first(where: { $0.id == dragInfo.chordId }),
              sourceSection.id == section.id,
              sourceChord.barIndex == barIndex else {
            return
        }

        if lastChordReorderTargetId == targetChord.id {
            return
        }

        let didMove = withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            moveChordToTargetIndex(
                sourceSectionId: dragInfo.sourceSectionId,
                chordId: dragInfo.chordId,
                targetChordId: targetChord.id
            )
        }
        if didMove {
            lastChordReorderTargetId = targetChord.id
        }
    }

    private func handleChordSlotDrop(
        _ providers: [NSItemProvider],
        targetChord: ChordEvent
    ) -> Bool {
        let handled = loadChordPayload(from: providers) { payload in
            _ = moveChordToTargetIndex(
                sourceSectionId: payload.sourceSectionId,
                chordId: payload.chordId,
                targetChordId: targetChord.id
            )
            draggingChord = nil
            lastChordReorderTargetId = nil
        }
        return handled
    }

    private func chordSlotDropDelegate(for chord: ChordEvent) -> ChordSlotDropDelegate {
        ChordSlotDropDelegate(
            targetChord: chord,
            onItemHovered: { target in
                handleChordSlotHover(targetChord: target)
            },
            onDrop: { target, providers in
                handleChordSlotDrop(providers, targetChord: target)
            },
            onExit: { lastChordReorderTargetId = nil }
        )
    }
    
    private func loadChordPayload(
        from providers: [NSItemProvider],
        perform: @escaping ((sourceSectionId: UUID, chordId: UUID)) -> Void
    ) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else {
            return false
        }
        
        provider.loadObject(ofClass: NSString.self) { object, _ in
            let stringValue: String?
            if let value = object as? String {
                stringValue = value
            } else if let value = object as? NSString {
                stringValue = value as String
            } else {
                stringValue = nil
            }
            
            guard let stringValue,
                  let payload = parseChordPayload(stringValue) else {
                return
            }
            
            DispatchQueue.main.async {
                perform(payload)
            }
        }
        
        return true
    }
    
    private func parseChordPayload(_ value: String) -> (sourceSectionId: UUID, chordId: UUID)? {
        let parts = value.split(separator: "|")
        guard parts.count == 2,
              let sectionId = UUID(uuidString: String(parts[0])),
              let chordId = UUID(uuidString: String(parts[1])) else {
            return nil
        }
        return (sectionId, chordId)
    }
    
    private func moveChord(
        chordId: UUID,
        sourceSectionId: UUID,
        targetBeatOffset: Double
    ) {
        guard let sourceSection = sectionById(sourceSectionId),
              let chord = sourceSection.chordEvents.first(where: { $0.id == chordId }) else {
            return
        }
        
        let originalBarIndex = chord.barIndex
        
        let excludeChord = sourceSection.id == section.id ? chord : nil
        guard canPlaceChord(
            chord,
            targetBeatOffset: targetBeatOffset,
            excluding: excludeChord
        ) else {
            return
        }
        
        if sourceSection.id != section.id {
            if let index = sourceSection.chordEvents.firstIndex(where: { $0.id == chord.id }) {
                sourceSection.chordEvents.remove(at: index)
            }
            chord.sectionTemplate = section
            section.chordEvents.append(chord)
        }
        
        chord.barIndex = barIndex
        chord.beatOffset = targetBeatOffset
        
        if originalBarIndex != barIndex {
            compactBarChords(in: sourceSection, barIndex: originalBarIndex)
        }
        
        compactBarChords(in: section, barIndex: barIndex)
    }

    private func moveChordToTargetIndex(
        sourceSectionId: UUID,
        chordId: UUID,
        targetChordId: UUID
    ) -> Bool {
        guard let sourceSection = sectionById(sourceSectionId),
              let sourceChord = sourceSection.chordEvents.first(where: { $0.id == chordId }) else {
            return false
        }

        let originalBarIndex = sourceChord.barIndex
        let isSameSection = sourceSection.id == section.id
        let isSameBar = isSameSection && sourceChord.barIndex == barIndex

        let ordered = section.chordEvents
            .filter { $0.barIndex == barIndex }
            .sorted { $0.beatOffset < $1.beatOffset }

        guard let targetIndex = ordered.firstIndex(where: { $0.id == targetChordId }) else {
            return false
        }

        var working = ordered
        var sourceIndex: Int?
        if isSameBar, let index = working.firstIndex(where: { $0.id == sourceChord.id }) {
            sourceIndex = index
            working.remove(at: index)
        }

        let destinationIndex: Int
        if let sourceIndex {
            destinationIndex = sourceIndex < targetIndex ? min(targetIndex, working.count) : targetIndex
        } else {
            destinationIndex = targetIndex
        }

        if !isSameBar {
            let totalDuration = working.reduce(0.0) { $0 + $1.duration } + sourceChord.duration
            guard totalDuration <= Double(beatsPerBar) + 0.0001 else {
                return false
            }
        }

        if !isSameSection {
            if let index = sourceSection.chordEvents.firstIndex(where: { $0.id == sourceChord.id }) {
                sourceSection.chordEvents.remove(at: index)
            }
            sourceChord.sectionTemplate = section
            section.chordEvents.append(sourceChord)
        }

        working.insert(sourceChord, at: destinationIndex)

        var beat = 0.0
        for chord in working {
            chord.barIndex = barIndex
            chord.beatOffset = beat
            beat += chord.duration
        }

        if originalBarIndex != barIndex {
            compactBarChords(in: sourceSection, barIndex: originalBarIndex)
        }

        return true
    }

    private func compactBarChords(in section: SectionTemplate, barIndex: Int) {
        let chords = section.chordEvents
            .filter { $0.barIndex == barIndex }
            .sorted { $0.beatOffset < $1.beatOffset }

        var beat = 0.0
        for chord in chords {
            chord.beatOffset = beat
            beat += chord.duration
        }
    }
    
    private func nextAvailableBeat(excluding excluded: ChordEvent?) -> Double {
        let chordsInBar = section.chordEvents.filter { event in
            event.barIndex == barIndex && event.id != excluded?.id
        }
        let endPositions = chordsInBar.map { $0.beatOffset + $0.duration }
        return min(endPositions.max() ?? 0, Double(beatsPerBar))
    }
    
    private func nextAvailableBeat(
        for duration: Double,
        startingAt startBeat: Double,
        excluding excluded: ChordEvent?
    ) -> Double? {
        let maxStart = Double(beatsPerBar) - duration
        guard maxStart >= 0 else { return nil }
        guard startBeat <= maxStart else { return nil }
        
        var beat = max(0, startBeat)
        beat = (beat * 2).rounded(.up) / 2
        
        while beat <= maxStart + 0.0001 {
            if canPlaceDuration(duration, targetBeatOffset: beat, excluding: excluded) {
                return beat
            }
            beat += 0.5
        }
        
        return nil
    }
    
    private func canPlaceChord(
        _ chord: ChordEvent,
        targetBeatOffset: Double,
        excluding excluded: ChordEvent?
    ) -> Bool {
        canPlaceDuration(
            chord.duration,
            targetBeatOffset: targetBeatOffset,
            excluding: excluded
        )
    }
    
    private func canPlaceDuration(
        _ duration: Double,
        targetBeatOffset: Double,
        excluding excluded: ChordEvent?
    ) -> Bool {
        let endBeat = targetBeatOffset + duration
        guard endBeat <= Double(beatsPerBar) else { return false }
        
        let chordsInBar = section.chordEvents.filter { event in
            event.barIndex == barIndex && event.id != excluded?.id
        }
        
        for existing in chordsInBar {
            let existingStart = existing.beatOffset
            let existingEnd = existing.beatOffset + existing.duration
            let overlaps = max(existingStart, targetBeatOffset) < min(existingEnd, endBeat)
            if overlaps {
                return false
            }
        }
        
        return true
    }
    
    private func sectionById(_ id: UUID) -> SectionTemplate? {
        project.arrangementItems
            .compactMap { $0.sectionTemplate }
            .first { $0.id == id }
    }

}

struct ChordSlotButton: View {
    let section: SectionTemplate
    let barIndex: Int
    let beatOffset: Double
    let isHalf: Bool
    @Binding var selectedSlot: ChordSlot?
    @Binding var draggingChord: ChordDragInfo?
    
    private var chord: ChordEvent? {
        section.chordEvents.first { chord in
            chord.barIndex == barIndex && chord.beatOffset == beatOffset
        }
    }
    
    var body: some View {
        Group {
            if let chord = chord {
                chordPill(text: chord.display)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedSlot = ChordSlot(
                            barIndex: barIndex,
                            beatOffset: beatOffset,
                            isHalf: isHalf,
                            sectionId: section.id
                        )
                    }
                    .onDrag {
                        draggingChord = ChordDragInfo(
                            sourceSectionId: section.id,
                            chordId: chord.id,
                            duration: chord.duration
                        )
                        return NSItemProvider(object: dragPayload(for: chord) as NSString)
                    } preview: {
                        chordPillPreview(text: chord.display)
                            .padding(4)
                    }
            }
        }
    }

    private func dragPayload(for chord: ChordEvent) -> String {
        "\(section.id.uuidString)|\(chord.id.uuidString)"
    }
    
    private func chordPill(text: String) -> some View {
        chordPillBase(text: text)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func chordPillPreview(text: String) -> some View {
        chordPillBase(text: text)
            .fixedSize()
    }
    
    private func chordPillBase(text: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [
                            section.color.opacity(0.7),
                            section.color.opacity(0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
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
    @State private var selectedColor: SectionColor = .purple
    
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
                                    bars = 1
                                    // Auto-select the color for this template
                                    selectedColor = colorFromHex(preset.colorHex)
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
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Color")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                            ForEach(SectionColor.allCases) { color in
                                Button {
                                    selectedColor = color
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(color.color)
                                            .frame(width: 50, height: 50)
                                        
                                        if selectedColor == color {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.title3)
                                                .foregroundStyle(.white)
                                        }
                                    }
                                }
                            }
                        }
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
        let section = SectionTemplate(
            name: sectionName,
            bars: 1,
            colorHex: selectedColor.hex
        )
        let arrangementItem = ArrangementItem(orderIndex: project.arrangementItems.count)
        arrangementItem.sectionTemplate = section
        
        project.arrangementItems.append(arrangementItem)
        
        try? modelContext.save()
        onSectionCreated(section)
        dismiss()
    }
    
    private func colorFromHex(_ hex: String) -> SectionColor {
        SectionColor.allCases.first { $0.hex == hex } ?? .purple
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
    
    var colorHex: String {
        switch self {
        case .intro: return SectionColor.green.hex
        case .verse: return SectionColor.cyan.hex
        case .chorus: return SectionColor.purple.hex
        case .bridge: return SectionColor.orange.hex
        case .solo: return SectionColor.pink.hex
        case .outro: return SectionColor.blue.hex
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
    
    @State private var selectedRoot: String
    @State private var selectedQuality: ChordQuality
    @State private var selectedExtensions: [String]
    @State private var duration: Double  // Changed to Double for half-beats
    @State private var showingSuggestions = true
    @State private var showingDiagram = false
    @State private var selectedTab: SuggestionTab = .smart
    
    // Cached values to avoid recalculation
    private let existingChord: ChordEvent?
    private let cachedLastChord: ChordEvent?
    private let cachedSmartSuggestions: [ChordSuggestion]
    private let cachedDiatonicChords: [ChordSuggestion]
    private let cachedPopularProgressions: [(name: String, progression: [ChordSuggestion])]
    
    // Calculate maximum available duration for this slot
    private var maxAvailableDuration: Double {
        let currentBarEndBeat = Double((slot.barIndex + 1) * project.timeTop)
        
        // Find all chords after this slot in the same bar
        let chordsAfter = section.chordEvents.filter { 
            $0.barIndex == slot.barIndex && $0.beatOffset > slot.beatOffset 
        }.sorted { $0.beatOffset < $1.beatOffset }
        
        if let nextChord = chordsAfter.first {
            // Space available until next chord
            return nextChord.beatOffset - slot.beatOffset
        } else {
            // Space available until end of bar
            return currentBarEndBeat - Double(slot.barIndex * project.timeTop) - slot.beatOffset
        }
    }
    
    // Available duration options based on space
    private var availableDurations: [Double] {
        let all: [Double] = [0.5, 1.0, 2.0, 4.0]
        return all.filter { $0 <= maxAvailableDuration }
    }
    
    enum SuggestionTab: String, CaseIterable {
        case smart = "Smart"
        case diatonic = "In Key"
        case progressions = "Popular"
    }
    
    private let roots = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    private let commonExtensions = ["7", "9", "11", "13", "sus2", "sus4", "add9"]
    
    private var accentColor: Color { section.color }
    
    // Use cached values instead of computed properties for better performance
    private var lastChord: ChordEvent? { cachedLastChord }
    private var smartSuggestions: [ChordSuggestion] { cachedSmartSuggestions }
    private var diatonicChords: [ChordSuggestion] { cachedDiatonicChords }
    private var popularProgressions: [(name: String, progression: [ChordSuggestion])] { cachedPopularProgressions }
    
    init(section: SectionTemplate, slot: ChordSlot, project: Project) {
        self.section = section
        self.slot = slot
        self.project = project
        
        let existingChord = section.chordEvents.first { chord in
            chord.barIndex == slot.barIndex && chord.beatOffset == slot.beatOffset
        }
        self.existingChord = existingChord
        
        _selectedRoot = State(initialValue: existingChord?.root ?? project.keyRoot)
        _selectedQuality = State(initialValue: existingChord?.quality ?? .major)
        _selectedExtensions = State(initialValue: existingChord?.extensions ?? [])
        
        // Calculate and cache expensive values once during initialization
        self.cachedLastChord = section.chordEvents.filter { 
            $0.barIndex < slot.barIndex || 
            ($0.barIndex == slot.barIndex && $0.beatOffset < slot.beatOffset)
        }.max(by: { a, b in
            if a.barIndex != b.barIndex {
                return a.barIndex < b.barIndex
            }
            return a.beatOffset < b.beatOffset
        })
        
        self.cachedSmartSuggestions = ChordSuggestionEngine.suggestNextChord(
            after: cachedLastChord,
            inKey: project.keyRoot,
            mode: project.keyMode
        )
        
        self.cachedDiatonicChords = ChordSuggestionEngine.diatonicChords(
            forKey: project.keyRoot,
            mode: project.keyMode
        )
        
        self.cachedPopularProgressions = ChordSuggestionEngine.popularProgressions(
            forKey: project.keyRoot,
            mode: project.keyMode
        )
        
        // Calculate initial duration - will be constrained by maxAvailableDuration
        let currentBarEndBeat = Double((slot.barIndex + 1) * project.timeTop)
        let chordsAfter = section.chordEvents.filter { 
            $0.barIndex == slot.barIndex && $0.beatOffset > slot.beatOffset 
        }.sorted { $0.beatOffset < $1.beatOffset }
        
        let maxDuration: Double
        if let nextChord = chordsAfter.first {
            maxDuration = nextChord.beatOffset - slot.beatOffset
        } else {
            maxDuration = currentBarEndBeat - Double(slot.barIndex * project.timeTop) - slot.beatOffset
        }
        
        let startingDuration = existingChord?.duration ?? min(1.0, maxDuration)
        _duration = State(initialValue: min(startingDuration, maxDuration))
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 28) {
                    chordPreviewSection
                    suggestionsSection
                    rootNoteSection
                    qualitySection
                    extensionsSection
                    durationSection
                    addChordButton
                    if existingChord != nil {
                        removeChordButton
                    }
                }
                .padding(24)
            }
            .navigationTitle(existingChord == nil ? "Add Chord" : "Edit Chord")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        addChord()
                    } label: {
                        Text(existingChord == nil ? "Add" : "Save")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(accentColor)
                            )
                    }
                }
            }
        }
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.05, blue: 0.15),
                Color(red: 0.1, green: 0.05, blue: 0.2),
                Color.black
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var chordPreviewSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(chordDisplay)
                        .font(.system(size: 56, weight: .bold))
                        .foregroundStyle(accentColor)
                    
                    Text("Bar \(slot.barIndex + 1) • Beat \(slot.beatOffset + 1)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        showingDiagram.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: showingDiagram ? "chevron.up.circle.fill" : "music.note.list")
                            .font(.title3)
                        if !showingDiagram {
                            Text("View Diagram")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(showingDiagram ? accentColor.opacity(0.3) : accentColor)
                    )
                }
            }
            
            if showingDiagram {
                ChordDiagramView(
                    root: selectedRoot,
                    quality: selectedQuality,
                    extensions: selectedExtensions,
                    accentColor: accentColor
                )
            }
        }
        .padding(.vertical, 12)
    }
    
    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    showingSuggestions.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(accentColor)
                    Text("Suggestions")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Image(systemName: showingSuggestions ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
            
            if showingSuggestions {
                VStack(spacing: 12) {
                    Picker("Suggestions", selection: $selectedTab) {
                        ForEach(SuggestionTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(accentColor)
                    
                    switch selectedTab {
                    case .smart:
                        smartSuggestionsView
                    case .diatonic:
                        diatonicChordsView
                    case .progressions:
                        progressionsView
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(accentColor.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(accentColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var rootNoteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Root Note")
                .font(.subheadline.weight(.semibold))
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
                                    .fill(selectedRoot == root ? accentColor : Color.white.opacity(0.05))
                            )
                    }
                }
            }
        }
    }
    
    private var qualitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quality")
                .font(.subheadline.weight(.semibold))
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
                                    .fill(selectedQuality == quality ? accentColor : Color.white.opacity(0.05))
                            )
                    }
                }
            }
        }
    }
    
    private var extensionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Extensions (Max 2)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                ForEach(commonExtensions, id: \.self) { ext in
                    Button {
                        if selectedExtensions.contains(ext) {
                            selectedExtensions.removeAll { $0 == ext }
                        } else if selectedExtensions.count < 2 {
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
                                    .fill(selectedExtensions.contains(ext) ? accentColor : Color.white.opacity(0.05))
                            )
                            .opacity((selectedExtensions.count >= 2 && !selectedExtensions.contains(ext)) ? 0.5 : 1.0)
                    }
                    .disabled(selectedExtensions.count >= 2 && !selectedExtensions.contains(ext))
                }
            }
            
            if selectedExtensions.count >= 2 {
                Text("Maximum 2 extensions selected")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }
    
    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Duration")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                
                Spacer()
                
                Text("Max: \(String(format: "%.1f", maxAvailableDuration)) beats")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Quick duration buttons
            HStack(spacing: 8) {
                ForEach([0.5, 1.0, 2.0, 4.0], id: \.self) { dur in
                    let isAvailable = dur <= maxAvailableDuration
                    Button {
                        if isAvailable {
                            duration = min(dur, maxAvailableDuration)
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: durationIcon(for: dur))
                                .font(.title3)
                            Text(durationLabel(for: dur))
                                .font(.caption2.weight(.medium))
                        }
                        .foregroundStyle(duration == dur ? .white : (isAvailable ? .secondary : .secondary.opacity(0.3)))
                        .frame(maxWidth: .infinity)
                        .frame(height: 65)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(duration == dur ? accentColor : Color.white.opacity(0.05))
                        )
                    }
                    .disabled(!isAvailable)
                    .opacity(isAvailable ? 1.0 : 0.5)
                }
            }
            
            // Fine tune controls
            HStack(spacing: 16) {
                Button {
                    if duration > 0.5 {
                        duration -= 0.5
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(accentColor)
                }
                .disabled(duration <= 0.5)
                
                Spacer()
                
                VStack(spacing: 4) {
                    Text(String(format: "%.1f", duration))
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    
                    Text("beats")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button {
                    if duration < min(8.0, maxAvailableDuration) {
                        duration += 0.5
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(accentColor)
                }
                .disabled(duration >= maxAvailableDuration)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.03))
        )
    }
    
    private var addChordButton: some View {
        Button {
            addChord()
        } label: {
            Text(existingChord == nil ? "Add Chord" : "Save Chord")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(accentColor)
                )
        }
    }
    
    private var removeChordButton: some View {
        Button(role: .destructive) {
            removeChord()
        } label: {
            Text("Remove Chord")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(Color.red)
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
    
    private var smartSuggestionsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let last = lastChord {
                Text("After \(last.display)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Start your progression")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(smartSuggestions) { suggestion in
                        SuggestionChip(suggestion: suggestion, accentColor: accentColor) {
                            applySuggestion(suggestion)
                        }
                    }
                }
            }
        }
    }
    
    private var diatonicChordsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(diatonicChords) { suggestion in
                    SuggestionChip(suggestion: suggestion, accentColor: accentColor) {
                        applySuggestion(suggestion)
                    }
                }
            }
        }
    }
    
    private var progressionsView: some View {
        VStack(spacing: 12) {
            ForEach(popularProgressions.indices, id: \.self) { index in
                let progression = popularProgressions[index]
                VStack(alignment: .leading, spacing: 8) {
                    Text(progression.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(progression.progression) { chord in
                                Text(chord.display)
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(accentColor.opacity(0.2))
                                            .overlay(
                                                Capsule()
                                                    .stroke(accentColor.opacity(0.4), lineWidth: 1)
                                            )
                                    )
                                    .onTapGesture {
                                        applySuggestion(chord)
                                    }
                            }
                        }
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(accentColor.opacity(0.2), lineWidth: 1)
                        )
                )
            }
        }
    }
    
    private func applySuggestion(_ suggestion: ChordSuggestion) {
        selectedRoot = suggestion.root
        selectedQuality = suggestion.quality
        selectedExtensions = suggestion.extensions
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
    
    private func removeChord() {
        section.chordEvents.removeAll {
            $0.barIndex == slot.barIndex && $0.beatOffset == slot.beatOffset
        }
        dismiss()
    }
    
    private func durationIcon(for duration: Double) -> String {
        switch duration {
        case 0.5: return "music.note.list"
        case 1.0: return "music.note"
        case 2.0: return "music.note.list"
        case 4.0: return "music.quarternote.3"
        default: return "music.note"
        }
    }
    
    private func durationLabel(for duration: Double) -> String {
        switch duration {
        case 0.5: return "Half"
        case 1.0: return "1 Beat"
        case 2.0: return "2 Beats"
        case 4.0: return "4 Beats"
        default: return String(format: "%.1f", duration)
        }
    }
}

struct SuggestionChip: View {
    let suggestion: ChordSuggestion
    let accentColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(suggestion.display)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Text(suggestion.reason)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(accentColor.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(accentColor.opacity(suggestion.confidence), lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Key Picker

struct LinkedRecordingCard: View {
    let recording: Recording
    let isPlaying: Bool
    let onPlay: () -> Void
    
    var body: some View {
        Button(action: onPlay) {
            VStack(alignment: .leading, spacing: 8) {
                // Play button
                ZStack {
                    Circle()
                        .fill(
                            isPlaying ?
                                LinearGradient(colors: [.green, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                LinearGradient(colors: [recording.recordingType.color.opacity(0.3), recording.recordingType.color.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 26, height: 26)
                        .shadow(color: isPlaying ? Color.green.opacity(0.3) : recording.recordingType.color.opacity(0.2), radius: 6)
                    
                    if isPlaying {
                        Image(systemName: "pause.fill")
                            .font(.caption)
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: "play.fill")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .offset(x: 1)
                    }
                }
                
                // Info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 3) {
                        Image(systemName: recording.recordingType.icon)
                            .font(.caption2)
                        Text(recording.recordingType.rawValue)
                            .font(.caption2)
                    }
                    .foregroundStyle(recording.recordingType.color)
                    
                    Text(recording.name)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    Text(formatDuration(recording.duration))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        isPlaying ?
                            Color.green.opacity(0.1) :
                            Color.white.opacity(0.05)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                isPlaying ?
                                    Color.green.opacity(0.5) :
                                    Color.white.opacity(0.1),
                                lineWidth: isPlaying ? 1.5 : 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Section Editor Sheet

struct SectionEditorSheet: View {
    @Bindable var section: SectionTemplate
    @Environment(\.dismiss) private var dismiss
    
    @State private var tempName: String = ""
    @State private var selectedColor: SectionColor = .purple
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Section Name")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    
                    TextField("e.g., Verse 1", text: $tempName)
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
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Color")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(SectionColor.allCases) { color in
                            Button {
                                selectedColor = color
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(color.color)
                                        .frame(width: 50, height: 50)
                                    
                                    if selectedColor == color {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                        }
                    }
                }
                
                Spacer()
                
                Button {
                    saveChanges()
                } label: {
                    Text("Save Changes")
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
                .disabled(tempName.isEmpty)
            }
            .padding(24)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.15),
                        Color(red: 0.1, green: 0.05, blue: 0.2),
                        Color.black
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .navigationTitle("Edit Section")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium])
        .onAppear {
            tempName = section.name
            selectedColor = colorFromHex(section.colorHex)
        }
    }
    
    private func saveChanges() {
        section.name = tempName
        section.colorHex = selectedColor.hex
        dismiss()
    }
    
    private func colorFromHex(_ hex: String?) -> SectionColor {
        guard let hex else { return .purple }
        return SectionColor.allCases.first { $0.hex == hex } ?? .purple
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

// MARK: - View All Sections Card
struct ViewAllSectionsCard: View {
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.title3)
                        .foregroundStyle(isSelected ? .white : .secondary)
                    
                    Spacer()
                }
                
                Text("View All")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .lineLimit(1)
                
                Text("Sections")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(width: 120)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.purple : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
