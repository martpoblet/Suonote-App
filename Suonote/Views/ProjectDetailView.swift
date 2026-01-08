import SwiftUI
import SwiftData

// MARK: - Project Detail View
/// Vista principal del proyecto que contiene las 3 tabs principales:
/// - Tab 0: Compose (Composición de acordes y estructura)
/// - Tab 1: Lyrics (Edición de letras)
/// - Tab 2: Record (Grabaciones de audio)
struct ProjectDetailView: View {
    // MARK: - Properties
    @Bindable var project: Project
    @State private var selectedTab: ProjectTab = .compose
    @State private var showingEditSheet = false
    @State private var showingStatusPicker = false
    
    private enum ProjectTab: Int, CaseIterable {
        case compose
        case studio
        case lyrics
        case record
        
        var title: String {
            switch self {
            case .compose: return "Compose"
            case .studio: return "Studio"
            case .lyrics: return "Lyrics"
            case .record: return "Record"
            }
        }
        
        var icon: String {
            switch self {
            case .compose: return "music.note.list"
            case .studio: return "square.grid.2x2"
            case .lyrics: return "text.quote"
            case .record: return "waveform.circle.fill"
            }
        }

        var tintColor: Color {
            switch self {
            case .compose: return SectionColor.purple.color
            case .studio: return SectionColor.cyan.color
            case .lyrics: return SectionColor.pink.color
            case .record: return SectionColor.red.color
            }
        }
    }
    
    // MARK: - Body
    var body: some View {
        ZStack {
            ProjectBackgroundView()
            
            // MARK: Tab Content
            /// Contenido dinámico según la tab seleccionada
            TabView(selection: $selectedTab) {
                ProjectTabContainer {
                    ComposeTabView(project: project)
                }
                    .tag(ProjectTab.compose)
                    .tabItem {
                        Label(ProjectTab.compose.title, systemImage: ProjectTab.compose.icon)
                    }
                
                ProjectTabContainer {
                    StudioTabView(project: project)
                }
                    .tag(ProjectTab.studio)
                    .tabItem {
                        Label(ProjectTab.studio.title, systemImage: ProjectTab.studio.icon)
                    }
                
                ProjectTabContainer {
                    LyricsTabView(project: project)
                }
                    .tag(ProjectTab.lyrics)
                    .tabItem {
                        Label(ProjectTab.lyrics.title, systemImage: ProjectTab.lyrics.icon)
                    }
                
                ProjectTabContainer {
                    RecordingsTabView(project: project)
                }
                    .tag(ProjectTab.record)
                    .tabItem {
                        Label(ProjectTab.record.title, systemImage: ProjectTab.record.icon)
                    }
            }
            .tabViewStyle(.automatic)
            .tint(selectedTab.tintColor)
            .padding(.top, 1)  // Small padding to prevent overlap
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // MARK: Toolbar - Title
            ToolbarItem(placement: .principal) {
                VStack(spacing: 4) {
                    // Título del proyecto
                    Text(project.title)
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                    
                    // Badge de estado (Idea, In Progress, etc.)
                    Button {
                        showingStatusPicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: statusIcon(for: project.status))
                                .font(.system(size: 10, weight: .bold))
                            Text(project.status.rawValue)
                                .font(.caption2.weight(.bold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(statusColor(for: project.status).opacity(0.25))
                        .foregroundStyle(statusColor(for: project.status))
                        .clipShape(Capsule())
                    }
                }
            }
            
            // MARK: Toolbar - Edit Button
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingEditSheet = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            }
        }
        // MARK: Sheets
        .sheet(isPresented: $showingEditSheet) {
            EditProjectSheet(project: project)
        }
        .sheet(isPresented: $showingStatusPicker) {
            StatusPickerSheet(project: project)
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Helper Methods
    
    /// Retorna el ícono SF Symbol para cada estado
    private func statusIcon(for status: ProjectStatus) -> String {
        switch status {
        case .idea: return "lightbulb.fill"
        case .inProgress: return "hammer.fill"
        case .polished: return "sparkles"
        case .finished: return "checkmark.seal.fill"
        case .archived: return "archivebox.fill"
        }
    }
    
    /// Retorna el color asociado a cada estado del proyecto
    private func statusColor(for status: ProjectStatus) -> Color {
        switch status {
        case .idea: return .yellow
        case .inProgress: return .orange
        case .polished: return .purple
        case .finished: return .green
        case .archived: return .gray
        }
    }
    
}

struct ProjectBackgroundView: View {
    static let gradient = LinearGradient(
        colors: [
            Color(red: 0.05, green: 0.05, blue: 0.15),
            Color(red: 0.1, green: 0.05, blue: 0.2),
            Color.black
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var body: some View {
        Self.gradient
            .ignoresSafeArea()
    }
}

struct ProjectTabContainer<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            ProjectBackgroundView()
            content
        }
    }
}

// MARK: - Edit Project Sheet

struct EditProjectSheet: View {
    @Bindable var project: Project
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var tempTitle: String = ""
    @State private var tempBPM: Int = 120
    @State private var tempTimeTop: Int = 4
    @State private var tempTimeBottom: Int = 4
    @State private var tempKeyRoot: String = "C"
    @State private var tempKeyMode: KeyMode = .major
    @State private var tempTags: [String] = []
    @State private var newTag: String = ""
    @State private var tempStatus: ProjectStatus = .idea
    @State private var showingTimeSignatureWarning = false
    
    private let roots = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    private let timeSignatures = TimeSignaturePreset.allCases
    
    private var timeSignatureChanged: Bool {
        tempTimeTop != project.timeTop || tempTimeBottom != project.timeBottom
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Title
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Project Title")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        
                        TextField("Project name", text: $tempTitle)
                            .textFieldStyle(.plain)
                            .font(.title3)
                            .padding(16)
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
                    
                    // Status
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Status")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                            ForEach(ProjectStatus.allCases, id: \.self) { status in
                                Button {
                                    tempStatus = status
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: statusIconFor(status))
                                            .font(.caption)
                                        Text(status.rawValue)
                                            .font(.subheadline.weight(.semibold))
                                    }
                                    .foregroundStyle(tempStatus == status ? .white : .secondary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(tempStatus == status ? statusColorFor(status).opacity(0.3) : Color.white.opacity(0.05))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(tempStatus == status ? statusColorFor(status) : Color.white.opacity(0.1), lineWidth: tempStatus == status ? 2 : 1)
                                            )
                                    )
                                }
                            }
                        }
                    }
                    
                    // BPM
                    BPMSelector(bpm: $tempBPM, timeTop: tempTimeTop, timeBottom: tempTimeBottom)
                    
                    // Time Signature
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Time Signature")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                            ForEach(timeSignatures) { signature in
                                Button {
                                    tempTimeTop = signature.top
                                    tempTimeBottom = signature.bottom
                                } label: {
                                    Text(signature.rawValue)
                                        .font(.headline.weight(.semibold))
                                        .foregroundStyle(isSelected(signature) ? .white : .secondary)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 44)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(isSelected(signature) ? Color.orange.opacity(0.3) : Color.white.opacity(0.05))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(isSelected(signature) ? Color.orange : Color.white.opacity(0.1), lineWidth: isSelected(signature) ? 2 : 1)
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // Key
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Key")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        
                        // Root note
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                            ForEach(roots, id: \.self) { root in
                                Button {
                                    tempKeyRoot = root
                                } label: {
                                    Text(root)
                                        .font(.headline)
                                        .foregroundStyle(tempKeyRoot == root ? .white : .secondary)
                                        .frame(height: 44)
                                        .frame(maxWidth: .infinity)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(tempKeyRoot == root ? Color.purple : Color.white.opacity(0.05))
                                        )
                                }
                            }
                        }
                        
                        // Mode
                        HStack(spacing: 12) {
                            Button {
                                tempKeyMode = .major
                            } label: {
                                Text("Major")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(tempKeyMode == .major ? .white : .secondary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(tempKeyMode == .major ? Color.purple : Color.white.opacity(0.05))
                                    )
                            }
                            
                            Button {
                                tempKeyMode = .minor
                            } label: {
                                Text("Minor")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(tempKeyMode == .minor ? .white : .secondary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(tempKeyMode == .minor ? Color.purple : Color.white.opacity(0.05))
                                    )
                            }
                        }
                    }
                    
                    // Tags
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tags")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        
                        // Current tags
                        if !tempTags.isEmpty {
                            FlowLayout(spacing: 8) {
                                ForEach(tempTags, id: \.self) { tag in
                                    HStack(spacing: 6) {
                                        Text(tag)
                                            .font(.subheadline)
                                        
                                        Button {
                                            tempTags.removeAll { $0 == tag }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.caption)
                                        }
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(Color.purple.opacity(0.3))
                                    )
                                }
                            }
                        }
                        
                        // Add tag
                        HStack {
                            TextField("Add tag", text: $newTag)
                                .textFieldStyle(.plain)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.05))
                                )
                                .foregroundStyle(.white)
                                .onSubmit {
                                    addTag()
                                }
                            
                            Button {
                                addTag()
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(Color.purple)
                            }
                            .disabled(newTag.isEmpty)
                        }
                    }
                }
                .padding(24)
            }
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
            .navigationTitle("Edit Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if timeSignatureChanged && !project.arrangementItems.isEmpty {
                            showingTimeSignatureWarning = true
                        } else {
                            saveChanges()
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
        .alert("Change Time Signature?", isPresented: $showingTimeSignatureWarning) {
            Button("Cancel", role: .cancel) {}
            Button("Save Anyway", role: .destructive) {
                saveChanges()
            }
        } message: {
            Text("Changing the time signature will affect the structure of your existing sections. Chord progressions may need adjustment.")
        }
        .onAppear {
            loadCurrentValues()
        }
    }
    
    private func loadCurrentValues() {
        tempTitle = project.title
        tempBPM = project.bpm
        let signature = TimeSignaturePreset.from(top: project.timeTop, bottom: project.timeBottom)
        tempTimeTop = signature.top
        tempTimeBottom = signature.bottom
        tempKeyRoot = project.keyRoot
        tempKeyMode = project.keyMode
        tempTags = project.tags
        tempStatus = project.status
    }
    
    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !tempTags.contains(trimmed) {
            tempTags.append(trimmed)
            newTag = ""
        }
    }

    private func isSelected(_ signature: TimeSignaturePreset) -> Bool {
        tempTimeTop == signature.top && tempTimeBottom == signature.bottom
    }
    
    private func saveChanges() {
        let oldTimeTop = project.timeTop
        let oldTimeBottom = project.timeBottom
        let shouldReflow = tempTimeTop != oldTimeTop || tempTimeBottom != oldTimeBottom

        project.title = tempTitle
        project.bpm = tempBPM
        project.timeTop = tempTimeTop
        project.timeBottom = tempTimeBottom
        project.keyRoot = tempKeyRoot
        project.keyMode = tempKeyMode
        project.tags = tempTags
        project.status = tempStatus
        if shouldReflow {
            project.applyTimeSignatureChange(
                oldTimeTop: oldTimeTop,
                oldTimeBottom: oldTimeBottom,
                newTimeTop: tempTimeTop,
                newTimeBottom: tempTimeBottom
            )
        }
        project.updatedAt = Date()
        
        try? modelContext.save()
        dismiss()
    }
    
    private func statusIconFor(_ status: ProjectStatus) -> String {
        switch status {
        case .idea: return "lightbulb.fill"
        case .inProgress: return "hammer.fill"
        case .polished: return "sparkles"
        case .finished: return "checkmark.seal.fill"
        case .archived: return "archivebox.fill"
        }
    }
    
    private func statusColorFor(_ status: ProjectStatus) -> Color {
        switch status {
        case .idea: return .yellow
        case .inProgress: return .orange
        case .polished: return .purple
        case .finished: return .green
        case .archived: return .gray
        }
    }
}

// MARK: - Flow Layout for Tags

struct StatusPickerSheet: View {
    @Bindable var project: Project
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("Update project status to track your progress")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                
                VStack(spacing: 12) {
                    ForEach(ProjectStatus.allCases, id: \.self) { status in
                        Button {
                            updateStatus(to: status)
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: statusIcon(for: status))
                                    .font(.title3)
                                    .foregroundStyle(statusColor(for: status))
                                    .frame(width: 32)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(status.rawValue)
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    
                                    Text(statusDescription(for: status))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                if project.status == status {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(statusColor(for: status))
                                }
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(project.status == status ? statusColor(for: status).opacity(0.15) : Color.white.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(project.status == status ? statusColor(for: status) : Color.white.opacity(0.1), 
                                                   lineWidth: project.status == status ? 2 : 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Spacer()
            }
            .padding(24)
            }
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
            .navigationTitle("Project Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium])
    }
    
    private func updateStatus(to status: ProjectStatus) {
        withAnimation {
            project.status = status
            project.updatedAt = Date()
            try? modelContext.save()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                dismiss()
            }
        }
    }
    
    private func statusIcon(for status: ProjectStatus) -> String {
        switch status {
        case .idea: return "lightbulb.fill"
        case .inProgress: return "hammer.fill"
        case .polished: return "sparkles"
        case .finished: return "checkmark.seal.fill"
        case .archived: return "archivebox.fill"
        }
    }
    
    private func statusColor(for status: ProjectStatus) -> Color {
        switch status {
        case .idea: return .yellow
        case .inProgress: return .orange
        case .polished: return .purple
        case .finished: return .green
        case .archived: return .gray
        }
    }
    
    private func statusDescription(for status: ProjectStatus) -> String {
        switch status {
        case .idea: return "Just an idea, needs work"
        case .inProgress: return "Actively working on it"
        case .polished: return "Almost there, refining details"
        case .finished: return "Complete and ready"
        case .archived: return "Put on hold or completed"
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

// MARK: - BPM Selector Component
struct BPMSelector: View {
    @Binding var bpm: Int
    let timeTop: Int
    let timeBottom: Int
    @StateObject private var tempoPreviewer = TempoPreviewer()
    
    private let gradientColors: [Color] = [.white, .white.opacity(0.7)]
    private let sliderGradient: [Color] = [.purple, .blue, .cyan]
    private let presets = [60, 90, 120, 140, 180]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tempo")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            
            VStack(spacing: 16) {
                bpmDisplay
                bpmSlider
                TempoPreviewButton(
                    previewer: tempoPreviewer,
                    bpm: bpm,
                    timeTop: timeTop,
                    timeBottom: timeBottom,
                    tint: .cyan
                )
                bpmPresets
            }
            .padding(20)
            .background(bpmBackground)
        }
    }
    
    private var bpmDisplay: some View {
        HStack {
            Text("\(bpm)")
                .font(.system(size: 72, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .monospacedDigit()
            
            Text("BPM")
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.top, 40)
        }
    }
    
    private var bpmSlider: some View {
        Slider(value: Binding(
            get: { Double(bpm) },
            set: { bpm = Int($0) }
        ), in: 40...240, step: 1)
        .tint(
            LinearGradient(
                colors: sliderGradient,
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }
    
    private var bpmPresets: some View {
        HStack {
            ForEach(presets, id: \.self) { preset in
                presetButton(preset)
            }
        }
    }
    
    private func presetButton(_ preset: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                bpm = preset
            }
        } label: {
            Text("\(preset)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(bpm == preset ? .white : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(bpm == preset ? Color.cyan.opacity(0.2) : Color.white.opacity(0.05))
                        .overlay(
                            Capsule()
                                .stroke(bpm == preset ? Color.cyan : Color.clear, lineWidth: 1)
                        )
                )
        }
    }
    
    private var bpmBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.white.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
            )
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Project.self, configurations: config)
    let project = Project(title: "Summer Vibes", status: .inProgress, tags: ["Pop"], bpm: 128)
    container.mainContext.insert(project)
    
    return NavigationStack {
        ProjectDetailView(project: project)
    }
    .modelContainer(container)
}
