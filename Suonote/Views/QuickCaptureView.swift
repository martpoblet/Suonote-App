import SwiftUI
import SwiftData
import AVFoundation

// MARK: - Quick Capture View (W1)
// A fast-access sheet for capturing musical ideas in under 10 seconds.
// Combines: title, chord sketch, BPM, key, voice memo note, and tags — all in one screen.

struct QuickCaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Form state
    @State private var title: String = ""
    @State private var ideaText: String = ""
    @State private var keyRoot: String = "C"
    @State private var keyMode: KeyMode = .major
    @State private var bpm: Int = 120
    @State private var chordSketch: String = ""
    @State private var selectedTags: [String] = []
    @State private var tagInput: String = ""
    @State private var isSaving: Bool = false
    @State private var savedProject: Project? = nil
    @FocusState private var focusedField: CaptureField?

    enum CaptureField { case title, idea, chord, tag }

    private let quickKeys = ["C", "G", "D", "A", "E", "F", "Bb", "Eb", "Am", "Em", "Dm"]
    private let quickBPMs = [75, 90, 100, 110, 120, 130, 140, 160]
    private let quickModes: [(label: String, mode: KeyMode)] = [
        ("Major", .major), ("Minor", .minor), ("Dorian", .dorian),
        ("Mixo", .mixolydian), ("Penta+", .pentatonicMajor), ("Blues", .blues)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {

                    // MARK: Title Field
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Idea Title", systemImage: "pencil")
                            .font(DesignSystem.Typography.calloutBold)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)

                        TextField("What's the vibe?", text: $title)
                            .font(DesignSystem.Typography.title3)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .focused($focusedField, equals: .title)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .chord }
                            .padding(DesignSystem.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                    .fill(DesignSystem.Colors.surfaceSecondary)
                            )
                    }

                    // MARK: Key + Mode
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Key", systemImage: "music.note")
                            .font(DesignSystem.Typography.calloutBold)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(quickKeys, id: \.self) { key in
                                    let cleanKey = key.replacingOccurrences(of: "m", with: "")
                                    Button(key) {
                                        keyRoot = cleanKey
                                        if key.hasSuffix("m") { keyMode = .minor }
                                    }
                                    .font(DesignSystem.Typography.calloutBold)
                                    .padding(.horizontal, 12).padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(keyRoot == cleanKey ?
                                                  DesignSystem.Colors.primary : DesignSystem.Colors.surfaceSecondary)
                                    )
                                    .foregroundStyle(keyRoot == cleanKey ? .white : DesignSystem.Colors.textPrimary)
                                }
                            }
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(quickModes, id: \.label) { item in
                                    Button(item.label) { keyMode = item.mode }
                                        .font(DesignSystem.Typography.caption)
                                        .padding(.horizontal, 10).padding(.vertical, 5)
                                        .background(
                                            Capsule()
                                                .fill(keyMode == item.mode ?
                                                      DesignSystem.Colors.primaryLight :
                                                      DesignSystem.Colors.surfaceSecondary)
                                        )
                                        .foregroundStyle(keyMode == item.mode ?
                                                         DesignSystem.Colors.primaryDark :
                                                         DesignSystem.Colors.textSecondary)
                                }
                            }
                        }
                    }

                    // MARK: BPM
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("BPM", systemImage: "metronome")
                                .font(DesignSystem.Typography.calloutBold)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                            Spacer()
                            Text("\(bpm)")
                                .font(DesignSystem.Typography.bodyBold)
                                .foregroundStyle(DesignSystem.Colors.primary)
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(quickBPMs, id: \.self) { tempo in
                                    Button("\(tempo)") { bpm = tempo }
                                        .font(DesignSystem.Typography.caption)
                                        .padding(.horizontal, 10).padding(.vertical, 5)
                                        .background(
                                            Capsule()
                                                .fill(bpm == tempo ?
                                                      DesignSystem.Colors.primary :
                                                      DesignSystem.Colors.surfaceSecondary)
                                        )
                                        .foregroundStyle(bpm == tempo ? .white : DesignSystem.Colors.textPrimary)
                                }
                            }
                        }

                        Slider(value: Binding(
                            get: { Double(bpm) },
                            set: { bpm = Int($0) }
                        ), in: 40...220, step: 1)
                        .tint(DesignSystem.Colors.primary)
                    }

                    // MARK: Chord Sketch
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Chord Sketch", systemImage: "guitars")
                            .font(DesignSystem.Typography.calloutBold)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)

                        TextField("e.g. Am F C G, or Dm7 G7 Cmaj7...", text: $chordSketch)
                            .font(DesignSystem.Typography.body)
                            .focused($focusedField, equals: .chord)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .idea }
                            .padding(DesignSystem.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                    .fill(DesignSystem.Colors.surfaceSecondary)
                            )

                        // Quick chord suggestions based on key
                        if !keyRoot.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(quickChordsForKey(), id: \.self) { chord in
                                        Button(chord) {
                                            chordSketch += (chordSketch.isEmpty ? "" : " ") + chord
                                        }
                                        .font(DesignSystem.Typography.caption)
                                        .padding(.horizontal, 8).padding(.vertical, 4)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(DesignSystem.Colors.primary.opacity(0.1))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 6)
                                                        .stroke(DesignSystem.Colors.primary.opacity(0.3), lineWidth: 1)
                                                )
                                        )
                                        .foregroundStyle(DesignSystem.Colors.primaryDark)
                                    }
                                }
                            }
                        }
                    }

                    // MARK: Notes / Idea Text
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Notes", systemImage: "text.bubble")
                            .font(DesignSystem.Typography.calloutBold)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)

                        ZStack(alignment: .topLeading) {
                            if ideaText.isEmpty {
                                Text("Lyric fragments, melody notes, production ideas...")
                                    .font(DesignSystem.Typography.body)
                                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                                    .padding(DesignSystem.Spacing.md)
                                    .allowsHitTesting(false)
                            }
                            TextEditor(text: $ideaText)
                                .font(DesignSystem.Typography.body)
                                .scrollContentBackground(.hidden)
                                .focused($focusedField, equals: .idea)
                                .frame(minHeight: 80)
                                .padding(DesignSystem.Spacing.sm)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                .fill(DesignSystem.Colors.surfaceSecondary)
                        )
                    }

                    // MARK: Tags
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Tags", systemImage: "tag")
                            .font(DesignSystem.Typography.calloutBold)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)

                        HStack {
                            TextField("Add a tag...", text: $tagInput)
                                .font(DesignSystem.Typography.body)
                                .focused($focusedField, equals: .tag)
                                .submitLabel(.done)
                                .onSubmit { addTag() }
                                .padding(DesignSystem.Spacing.sm)
                                .background(
                                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                        .fill(DesignSystem.Colors.surfaceSecondary)
                                )

                            Button("Add") { addTag() }
                                .font(DesignSystem.Typography.calloutBold)
                                .foregroundStyle(DesignSystem.Colors.primary)
                                .disabled(tagInput.trimmingCharacters(in: .whitespaces).isEmpty)
                        }

                        // Quick tag chips
                        let quickTags = ["melodic", "dark", "upbeat", "chill", "verse", "chorus", "bridge", "hook"]
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(quickTags, id: \.self) { tag in
                                    if !selectedTags.contains(tag) {
                                        Button("+ \(tag)") {
                                            selectedTags.append(tag)
                                        }
                                        .font(DesignSystem.Typography.caption2)
                                        .padding(.horizontal, 8).padding(.vertical, 4)
                                        .background(
                                            Capsule().fill(DesignSystem.Colors.surfaceSecondary)
                                        )
                                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                                    }
                                }
                            }
                        }

                        // Selected tags
                        if !selectedTags.isEmpty {
                            FlowLayout(spacing: 6) {
                                ForEach(selectedTags, id: \.self) { tag in
                                    HStack(spacing: 4) {
                                        Text(tag)
                                            .font(DesignSystem.Typography.caption)
                                        Button { selectedTags.removeAll { $0 == tag } } label: {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 9, weight: .bold))
                                        }
                                    }
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(
                                        Capsule().fill(DesignSystem.Colors.primary)
                                    )
                                    .foregroundStyle(.white)
                                }
                            }
                        }
                    }

                    // MARK: Save Button
                    Button { saveIdea() } label: {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                            }
                            Text(isSaving ? "Saving..." : "Save Idea")
                        }
                        .font(DesignSystem.Typography.bodyBold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                                .fill(title.isEmpty ? DesignSystem.Colors.textTertiary : DesignSystem.Colors.primary)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving)
                    .animatedPress()
                }
                .padding(DesignSystem.Spacing.xl)
            }
            .background(DesignSystem.Colors.background.ignoresSafeArea())
            .navigationTitle("Quick Capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    focusedField = .title
                }
            }
        }
    }

    // MARK: - Helpers

    private func quickChordsForKey() -> [String] {
        guard let keyIdx = MusicTheory.noteIndex(keyRoot) else { return [] }
        let scale = keyMode.intervals.map { MusicTheory.chromaticScale[(keyIdx + $0) % 12] }
        let qualities: [String] = keyMode.isMinor
            ? ["m", "", "m", "m", "", "", "dim"]
            : ["", "m", "m", "", "", "m", "dim"]
        return zip(scale, qualities).map { "\($0)\($1)" }
    }

    private func addTag() {
        let tag = tagInput.trimmingCharacters(in: .whitespaces).lowercased()
        guard !tag.isEmpty, !selectedTags.contains(tag) else { return }
        selectedTags.append(tag)
        tagInput = ""
    }

    private func saveIdea() {
        isSaving = true
        let projectTitle = title.isEmpty ? "New Idea" : title
        let project = Project(
            title: projectTitle,
            status: .idea,
            tags: selectedTags,
            keyRoot: keyRoot,
            keyMode: keyMode,
            bpm: bpm
        )

        // Add chord sketch as a verse section with notes
        if !chordSketch.isEmpty || !ideaText.isEmpty {
            let section = SectionTemplate(
                name: "Idea",
                bars: 4,
                notesText: [
                    chordSketch.isEmpty ? nil : "Chords: \(chordSketch)",
                    ideaText.isEmpty ? nil : ideaText
                ].compactMap { $0 }.joined(separator: "\n\n")
            )
            section.project = project
            project.sectionTemplates.append(section)

            let item = ArrangementItem(orderIndex: 0)
            item.sectionTemplate = section
            item.project = project
            project.arrangementItems.append(item)
        }

        modelContext.insert(project)

        do {
            try modelContext.save()
            HapticFeedback.success()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isSaving = false
                dismiss()
            }
        } catch {
            isSaving = false
        }
    }
}

// MARK: - Flow Layout Helper

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let containerWidth = proposal.width ?? 300
        var totalHeight: CGFloat = 0
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0

        for view in subviews {
            let viewSize = view.sizeThatFits(.unspecified)
            if lineWidth + viewSize.width + spacing > containerWidth, lineWidth > 0 {
                totalHeight += lineHeight + spacing
                lineWidth = 0
                lineHeight = 0
            }
            lineWidth += viewSize.width + spacing
            lineHeight = max(lineHeight, viewSize.height)
        }
        totalHeight += lineHeight
        return CGSize(width: containerWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for view in subviews {
            let viewSize = view.sizeThatFits(.unspecified)
            if x + viewSize.width > bounds.maxX, x > bounds.minX {
                y += lineHeight + spacing
                x = bounds.minX
                lineHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(viewSize))
            x += viewSize.width + spacing
            lineHeight = max(lineHeight, viewSize.height)
        }
    }
}
