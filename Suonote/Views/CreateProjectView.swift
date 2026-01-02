import SwiftUI
import SwiftData

struct CreateProjectView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var status: ProjectStatus = .idea
    @State private var tags: [String] = []
    @State private var tagInput = ""
    @State private var bpm = 120
    @State private var showingBPMPicker = false
    @FocusState private var isTitleFocused: Bool
    
    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color(red: 0.15, green: 0.05, blue: 0.25),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    Text("New Idea")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Button {
                        createProject()
                    } label: {
                        Text("Create")
                            .font(.headline)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(title.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1.0)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Title Section
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Title", systemImage: "music.note")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            
                            TextField("My awesome idea...", text: $title)
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                                .focused($isTitleFocused)
                                .padding(20)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color.white.opacity(0.05))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(
                                                    isTitleFocused ? 
                                                    LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing) :
                                                    LinearGradient(colors: [Color.white.opacity(0.1)], startPoint: .leading, endPoint: .trailing),
                                                    lineWidth: 2
                                                )
                                        )
                                )
                        }
                        
                        // Status Section
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Status", systemImage: "flag.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(ProjectStatus.allCases, id: \.self) { statusOption in
                                        StatusSelectionCard(
                                            status: statusOption,
                                            isSelected: status == statusOption
                                        ) {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                status = statusOption
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        // BPM Section
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Tempo", systemImage: "metronome")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            
                            VStack(spacing: 16) {
                                HStack {
                                    Text("\(bpm)")
                                        .font(.system(size: 72, weight: .bold, design: .rounded))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.white, .white.opacity(0.7)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                    
                                    Text("BPM")
                                        .font(.title3.weight(.medium))
                                        .foregroundStyle(.secondary)
                                        .padding(.top, 40)
                                }
                                
                                Slider(value: Binding(
                                    get: { Double(bpm) },
                                    set: { bpm = Int($0) }
                                ), in: 40...240, step: 1)
                                .tint(
                                    LinearGradient(
                                        colors: [.purple, .blue, .cyan],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                
                                HStack {
                                    ForEach([60, 90, 120, 140, 180], id: \.self) { preset in
                                        Button {
                                            withAnimation(.spring(response: 0.3)) {
                                                bpm = preset
                                            }
                                        } label: {
                                            Text("\(preset)")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(bpm == preset ? .white : .white.opacity(0.5))
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(
                                                    Capsule()
                                                        .fill(bpm == preset ? Color.white.opacity(0.15) : Color.clear)
                                                )
                                        }
                                    }
                                }
                            }
                            .padding(24)
                            .background(
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(Color.white.opacity(0.03))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 24)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            )
                        }
                        
                        // Tags Section
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Tags", systemImage: "tag.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            
                            VStack(spacing: 12) {
                                HStack(spacing: 12) {
                                    TextField("Add tag", text: $tagInput)
                                        .textFieldStyle(.plain)
                                        .foregroundStyle(.white)
                                        .onSubmit {
                                            addTag()
                                        }
                                    
                                    if !tagInput.isEmpty {
                                        Button {
                                            addTag()
                                        } label: {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.title3)
                                                .foregroundStyle(
                                                    LinearGradient(
                                                        colors: [.cyan, .blue],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                        }
                                    }
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.white.opacity(0.05))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                        )
                                )
                                
                                if !tags.isEmpty {
                                    FlowLayout(spacing: 8) {
                                        ForEach(tags, id: \.self) { tag in
                                            TagChip(tag: tag) {
                                                withAnimation(.spring(response: 0.3)) {
                                                    tags.removeAll { $0 == tag }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            isTitleFocused = true
        }
        .preferredColorScheme(.dark)
    }
    
    private func addTag() {
        let trimmed = tagInput.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty && !tags.contains(trimmed) {
            withAnimation(.spring(response: 0.3)) {
                tags.append(trimmed)
            }
            tagInput = ""
        }
    }
    
    private func createProject() {
        let finalTitle = title.trimmingCharacters(in: .whitespaces).isEmpty ? "New Idea" : title
        let project = Project(
            title: finalTitle,
            status: status,
            tags: tags,
            bpm: bpm
        )
        
        // Update timestamp to ensure it appears at top
        project.updatedAt = Date()
        
        // Insert into context
        modelContext.insert(project)
        
        // Force save
        do {
            try modelContext.save()
            print("✅ Project saved: \(project.title)")
            
            // Give SwiftData time to propagate changes before dismissing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                dismiss()
            }
        } catch {
            print("❌ Error saving project: \(error)")
            dismiss()
        }
    }
}

// MARK: - Supporting Views

struct StatusSelectionCard: View {
    let status: ProjectStatus
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? color : .white.opacity(0.4))
                
                Text(status.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.6))
            }
            .frame(width: 100, height: 100)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? color.opacity(0.15) : Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(isSelected ? color : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .scaleEffect(isSelected ? 1.0 : 0.9)
    }
    
    private var icon: String {
        switch status {
        case .idea: return "lightbulb.fill"
        case .inProgress: return "hammer.fill"
        case .polished: return "sparkles"
        case .finished: return "checkmark.seal.fill"
        case .archived: return "archivebox.fill"
        }
    }
    
    private var color: Color {
        switch status {
        case .idea: return .yellow
        case .inProgress: return .orange
        case .polished: return .purple
        case .finished: return .green
        case .archived: return .gray
        }
    }
}

struct TagChip: View {
    let tag: String
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Text(tag)
                .font(.subheadline.weight(.medium))
            
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .foregroundStyle(.cyan)
        .background(
            Capsule()
                .fill(Color.cyan.opacity(0.15))
                .overlay(
                    Capsule()
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, point) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }
    
    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0
        let maxWidth = proposal.width ?? .infinity
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            positions.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            maxX = max(maxX, currentX - spacing)
        }
        
        let finalHeight = currentY + lineHeight
        return (CGSize(width: maxX, height: finalHeight), positions)
    }
}

#Preview {
    CreateProjectView()
        .modelContainer(for: [Project.self])
}
