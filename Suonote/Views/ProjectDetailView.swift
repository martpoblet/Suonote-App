import SwiftUI
import SwiftData

struct ProjectDetailView: View {
    @Bindable var project: Project
    @State private var selectedTab = 0
    @State private var showingEditSheet = false
    @Namespace private var animation
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color(red: 0.1, green: 0.05, blue: 0.2),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Tab Bar
                customTabBar
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                
                // Content
                TabView(selection: $selectedTab) {
                    ComposeTabView(project: project)
                        .tag(0)
                    
                    LyricsTabView(project: project)
                        .tag(1)
                    
                    RecordingsTabView(project: project)
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 4) {
                    Text(project.title)
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                    
                    if !project.tags.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(project.tags.prefix(2), id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.purple)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        Capsule()
                                            .fill(Color.purple.opacity(0.2))
                                    )
                            }
                        }
                    }
                }
            }
            
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
        .sheet(isPresented: $showingEditSheet) {
            EditProjectSheet(project: project)
        }
        .preferredColorScheme(.dark)
    }
    
    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = index
                    }
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: tab.icon)
                            .font(.title3.weight(selectedTab == index ? .semibold : .regular))
                            .foregroundStyle(selectedTab == index ? .white : .white.opacity(0.5))
                        
                        Text(tab.title)
                            .font(.caption.weight(selectedTab == index ? .semibold : .regular))
                            .foregroundStyle(selectedTab == index ? .white : .white.opacity(0.5))
                        
                        if selectedTab == index {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(height: 3)
                                .matchedGeometryEffect(id: "tab", in: animation)
                        } else {
                            Capsule()
                                .fill(Color.clear)
                                .frame(height: 3)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private var tabs: [(title: String, icon: String)] {
        [
            ("Compose", "music.note.list"),
            ("Lyrics", "text.quote"),
            ("Record", "waveform.circle.fill")
        ]
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
    
    private let roots = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    private let timeBottoms = [2, 4, 8, 16]
    
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
                    
                    // BPM
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tempo (BPM)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        
                        HStack {
                            Button {
                                if tempBPM > 40 {
                                    tempBPM -= 1
                                }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(Color.cyan)
                            }
                            
                            Spacer()
                            
                            Text("\(tempBPM)")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .monospacedDigit()
                            
                            Spacer()
                            
                            Button {
                                if tempBPM < 300 {
                                    tempBPM += 1
                                }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(Color.cyan)
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    
                    // Time Signature
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Time Signature")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        
                        HStack(spacing: 16) {
                            // Top number
                            VStack(spacing: 8) {
                                Text("Beats per bar")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                Picker("", selection: $tempTimeTop) {
                                    ForEach(1...12, id: \.self) { num in
                                        Text("\(num)").tag(num)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 100, height: 100)
                                .clipped()
                            }
                            
                            Text("/")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            
                            // Bottom number
                            VStack(spacing: 8) {
                                Text("Note value")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                Picker("", selection: $tempTimeBottom) {
                                    ForEach(timeBottoms, id: \.self) { num in
                                        Text("\(num)").tag(num)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 100, height: 100)
                                .clipped()
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                )
                        )
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
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            loadCurrentValues()
        }
    }
    
    private func loadCurrentValues() {
        tempTitle = project.title
        tempBPM = project.bpm
        tempTimeTop = project.timeTop
        tempTimeBottom = project.timeBottom
        tempKeyRoot = project.keyRoot
        tempKeyMode = project.keyMode
        tempTags = project.tags
    }
    
    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !tempTags.contains(trimmed) {
            tempTags.append(trimmed)
            newTag = ""
        }
    }
    
    private func saveChanges() {
        project.title = tempTitle
        project.bpm = tempBPM
        project.timeTop = tempTimeTop
        project.timeBottom = tempTimeBottom
        project.keyRoot = tempKeyRoot
        project.keyMode = tempKeyMode
        project.tags = tempTags
        project.updatedAt = Date()
        
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Flow Layout for Tags

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
