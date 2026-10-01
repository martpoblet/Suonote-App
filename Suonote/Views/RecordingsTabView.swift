import SwiftUI
import SwiftData
import AVFoundation

/// The Record tab: one tap to capture an idea, then a calm list of takes
/// you can play, scrub, filter, rename, link, favorite, share and delete.
struct RecordingsTabView: View {
    @Bindable var project: Project
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var studioPlayback: StudioPlaybackEngine
    @StateObject private var audioManager = AudioRecordingManager()
    @StateObject private var player = RecordTakePlayer()

    @AppStorage(RecordPreferenceKey.countInBars) private var countInBars = 1
    @AppStorage(RecordPreferenceKey.clickEnabled) private var clickEnabled = false
    @AppStorage(RecordPreferenceKey.lastType) private var lastTypeRaw = RecordingType.voice.rawValue

    @State private var showingRecordingScreen = false
    @State private var autoStartRecording = true
    @State private var filterType: RecordingType?
    @State private var filterSectionId: UUID?
    @State private var favoritesOnly = false
    @State private var sortOrder: RecordingSortOrder = .dateDescending
    @State private var selectedRecordingForLink: Recording?
    @State private var selectedRecordingForDetail: Recording?
    @State private var recordingToDelete: Recording?
    @State private var recordingToRename: Recording?
    @State private var renameText = ""

    enum RecordingSortOrder: String, CaseIterable {
        case dateDescending = "Newest first"
        case dateAscending = "Oldest first"
        case nameAscending = "Name A–Z"
        case durationDescending = "Longest first"

        var title: String {
            switch self {
            case .dateDescending: return String(localized: "Newest first")
            case .dateAscending: return String(localized: "Oldest first")
            case .nameAscending: return String(localized: "Name A–Z")
            case .durationDescending: return String(localized: "Longest first")
            }
        }

        var icon: String {
            switch self {
            case .dateDescending: return "arrow.down"
            case .dateAscending: return "arrow.up"
            case .nameAscending: return "textformat"
            case .durationDescending: return "clock"
            }
        }
    }

    private var recordingType: RecordingType {
        RecordingType(rawValue: lastTypeRaw) ?? .voice
    }

    private var uniqueSections: [SectionTemplate] { project.recordUniqueSections }

    private var sectionsById: [UUID: SectionTemplate] {
        Dictionary(uniqueSections.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private var hasActiveFilters: Bool {
        filterType != nil || filterSectionId != nil || favoritesOnly
    }

    private var filteredAndSortedRecordings: [Recording] {
        var recordings = project.recordings
        if let type = filterType {
            recordings = recordings.filter { $0.recordingType == type }
        }
        if let sectionId = filterSectionId {
            recordings = recordings.filter { $0.linkedSectionId == sectionId }
        }
        if favoritesOnly {
            recordings = recordings.filter(\.isFavorite)
        }
        switch sortOrder {
        case .dateDescending: recordings.sort { $0.createdAt > $1.createdAt }
        case .dateAscending: recordings.sort { $0.createdAt < $1.createdAt }
        case .nameAscending: recordings.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .durationDescending: recordings.sort { $0.duration > $1.duration }
        }
        return recordings
    }

    /// Types that actually appear in this project (keeps the filter row short).
    private var presentTypes: [RecordingType] {
        let present = Set(project.recordings.map(\.recordingType))
        return RecordingType.allCases.filter { present.contains($0) }
    }

    /// Sections that have at least one linked take.
    private var linkedSections: [SectionTemplate] {
        let linked = Set(project.recordings.compactMap(\.linkedSectionId))
        return uniqueSections.filter { linked.contains($0.id) }
    }

    private var totalDuration: TimeInterval {
        project.recordings.reduce(0) { $0 + $1.duration }
    }

    // MARK: Body

    var body: some View {
        let recordings = filteredAndSortedRecordings
        let sectionMap = sectionsById

        List {
            Group {
                header
                    .padding(.top, DesignSystem.Spacing.md)
                    .rowStyle(top: 0, bottom: DesignSystem.Spacing.md)

                RecordHeroCard(
                    takeNumber: project.recordings.count + 1,
                    type: recordingType,
                    countInBars: $countInBars,
                    clickEnabled: $clickEnabled,
                    onSelectType: { lastTypeRaw = $0.rawValue },
                    onRecord: { openRecorder(autoStart: true) },
                    onMoreOptions: { openRecorder(autoStart: false) }
                )
                .rowStyle(top: 0, bottom: DesignSystem.Spacing.lg)

                if !project.recordings.isEmpty {
                    takesHeader(count: recordings.count)
                        .rowStyle(top: 0, bottom: DesignSystem.Spacing.xs)

                    filterChips
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: DesignSystem.Spacing.sm, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                if recordings.isEmpty {
                    emptyState
                        .rowStyle(top: DesignSystem.Spacing.md, bottom: DesignSystem.Spacing.xxl)
                } else {
                    ForEach(recordings) { recording in
                        takeRow(recording, linkedSection: recording.linkedSectionId.flatMap { sectionMap[$0] })
                            .rowStyle(top: DesignSystem.Spacing.xxs, bottom: DesignSystem.Spacing.xxs)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, DesignSystem.Spacing.xxxl, for: .scrollContent)
        .animation(DesignSystem.Animations.smoothSpring, value: recordings.map(\.id))
        .fullScreenCover(isPresented: $showingRecordingScreen) {
            ActiveRecordingView(
                project: project,
                audioManager: audioManager,
                recordingType: recordingType,
                initialLinkedSectionId: filterSectionId,
                autoStart: autoStartRecording
            )
        }
        .sheet(item: $selectedRecordingForLink) { recording in
            SectionLinkSheet(
                recording: recording,
                sections: uniqueSections,
                onLink: { link(recording, to: $0) }
            )
        }
        .sheet(item: $selectedRecordingForDetail) { recording in
            RecordingDetailView(
                recording: recording,
                sections: uniqueSections,
                player: player,
                onUpdate: {
                    project.updatedAt = Date()
                    try? modelContext.save()
                },
                onDelete: {
                    selectedRecordingForDetail = nil
                    // Let the sheet finish dismissing before asking.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        recordingToDelete = recording
                    }
                }
            )
        }
        .onAppear {
            audioManager.setup(project: project)
        }
        .onDisappear {
            player.stop()
        }
        // One thing plays at a time: a take pauses the song and vice versa.
        .onChange(of: player.isPlaying) { _, isPlaying in
            if isPlaying { pauseStudioIfNeeded() }
        }
        .onChange(of: studioPlayback.isPlaying) { _, isPlaying in
            if isPlaying { player.pause() }
        }
        .confirmationDialog(
            "Delete \(recordingToDelete?.name ?? String(localized: "take"))?",
            isPresented: Binding(get: { recordingToDelete != nil }, set: { if !$0 { recordingToDelete = nil } }),
            titleVisibility: .visible,
            presenting: recordingToDelete
        ) { recording in
            Button("Delete take", role: .destructive) { deleteRecording(recording) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("The audio file will be removed. This can't be undone.")
        }
        .alert(
            "Rename take",
            isPresented: Binding(get: { recordingToRename != nil }, set: { if !$0 { recordingToRename = nil } }),
            presenting: recordingToRename
        ) { recording in
            TextField("Take name", text: $renameText)
            Button("Save") { rename(recording) }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: Header

    private var header: some View {
        ScreenHeader(eyebrow: String(localized: "Record"), title: String(localized: "Takes"), subtitle: headerSubtitle) {
            if !project.recordings.isEmpty {
                sortMenu
            }
        }
    }

    private var headerSubtitle: String {
        let count = project.recordings.count
        switch count {
        case 0: return String(localized: "Catch it before it's gone.")
        default: return String(localized: "\(count) takes · \(RecordFormat.duration(totalDuration)) in all")
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort by", selection: $sortOrder) {
                ForEach(RecordingSortOrder.allCases, id: \.self) { order in
                    Label(order.title, systemImage: order.icon).tag(order)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel("Sort takes")
        .accessibilityValue(sortOrder.title)
    }

    private func takesHeader(count: Int) -> some View {
        SectionHeader(
            title: String(localized: "Takes"),
            detail: hasActiveFilters ? String(localized: "\(count) of \(project.recordings.count)") : "\(count)",
            actionTitle: hasActiveFilters ? String(localized: "Clear filters") : nil,
            action: hasActiveFilters ? { clearFilters() } : nil
        )
    }

    private var filterChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                SelectableChip(title: String(localized: "All"), isSelected: !hasActiveFilters) {
                    HapticFeedback.selection.trigger()
                    clearFilters()
                }
                SelectableChip(title: String(localized: "Favorites"), icon: "star.fill", isSelected: favoritesOnly) {
                    HapticFeedback.selection.trigger()
                    favoritesOnly.toggle()
                }
                if presentTypes.count > 1 {
                    ForEach(presentTypes, id: \.self) { type in
                        SelectableChip(title: type.recordDisplayName, icon: type.icon, isSelected: filterType == type) {
                            HapticFeedback.selection.trigger()
                            filterType = filterType == type ? nil : type
                        }
                    }
                }
                ForEach(linkedSections) { section in
                    SelectableChip(title: section.name, dot: section.color, isSelected: filterSectionId == section.id) {
                        HapticFeedback.selection.trigger()
                        filterSectionId = filterSectionId == section.id ? nil : section.id
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.gutter)
            .padding(.vertical, 1)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private var emptyState: some View {
        if project.recordings.isEmpty {
            VStack(spacing: DesignSystem.Spacing.sm) {
                BrandWavesMark(size: 34, animated: true)
                Text("No takes yet")
                    .font(DesignSystem.Typography.title2)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Text("Hum it, strum it, keep it. Every take lands here.")
                    .font(DesignSystem.Typography.italicSmall)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.xl)
        } else {
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("Nothing matches")
                    .font(DesignSystem.Typography.title3)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Text("No takes fit these filters.")
                    .font(DesignSystem.Typography.italicSmall)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                Button("Clear filters") { clearFilters() }
                    .buttonStyle(OutlineButtonStyle(compact: true))
                    .padding(.top, DesignSystem.Spacing.xxs)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.xl)
        }
    }

    // MARK: Rows

    private func takeRow(_ recording: Recording, linkedSection: SectionTemplate?) -> some View {
        RecordTakeRow(
            recording: recording,
            linkedSection: linkedSection,
            player: player,
            onOpen: { selectedRecordingForDetail = recording },
            onToggleFavorite: { toggleFavorite(recording) },
            onLinkSection: { selectedRecordingForLink = recording }
        )
        .contextMenu {
            Button {
                player.toggle(recording)
            } label: {
                Label(player.isPlaying(recording) ? "Pause" : "Play",
                      systemImage: player.isPlaying(recording) ? "pause" : "play")
            }
            Button {
                renameText = recording.name
                recordingToRename = recording
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            Button {
                toggleFavorite(recording)
            } label: {
                Label(recording.isFavorite ? "Unfavorite" : "Favorite",
                      systemImage: recording.isFavorite ? "star.slash" : "star")
            }
            Menu {
                Picker("Type", selection: Binding(
                    get: { recording.recordingType },
                    set: { recording.recordingType = $0; touch() }
                )) {
                    ForEach(RecordingType.allCases, id: \.self) { type in
                        Label(type.recordDisplayName, systemImage: type.icon).tag(type)
                    }
                }
            } label: {
                Label("Type", systemImage: recording.recordingType.icon)
            }
            if !uniqueSections.isEmpty {
                Menu {
                    Button {
                        link(recording, to: nil)
                    } label: {
                        Label("No section", systemImage: recording.linkedSectionId == nil ? "checkmark" : "circle.dashed")
                    }
                    ForEach(uniqueSections) { section in
                        Button {
                            link(recording, to: section.id)
                        } label: {
                            if recording.linkedSectionId == section.id {
                                Label(section.name, systemImage: "checkmark")
                            } else {
                                Text(section.name)
                            }
                        }
                    }
                } label: {
                    Label("Link to section", systemImage: "link")
                }
            }
            if let url = recording.recordFileURL {
                ShareLink(item: url, preview: SharePreview(recording.name)) {
                    Label("Share audio", systemImage: "square.and.arrow.up")
                }
            }
            Divider()
            Button(role: .destructive) {
                recordingToDelete = recording
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                recordingToDelete = recording
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                renameText = recording.name
                recordingToRename = recording
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            .tint(DesignSystem.Colors.textSecondary)
            Button {
                selectedRecordingForLink = recording
            } label: {
                Label("Link", systemImage: "link")
            }
            .tint(DesignSystem.Colors.primaryDark)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                toggleFavorite(recording)
            } label: {
                Label(recording.isFavorite ? "Unfavorite" : "Favorite",
                      systemImage: recording.isFavorite ? "star.slash.fill" : "star.fill")
            }
            .tint(DesignSystem.Colors.accent)
        }
    }

    // MARK: Actions

    private func openRecorder(autoStart: Bool) {
        player.stop()
        pauseStudioIfNeeded()
        autoStartRecording = autoStart
        showingRecordingScreen = true
    }

    private func pauseStudioIfNeeded() {
        if studioPlayback.isPlaying {
            studioPlayback.pause()
        }
    }

    private func clearFilters() {
        withAnimation(DesignSystem.Animations.quickSpring) {
            filterType = nil
            filterSectionId = nil
            favoritesOnly = false
        }
    }

    private func touch() {
        project.updatedAt = Date()
        try? modelContext.save()
    }

    private func toggleFavorite(_ recording: Recording) {
        recording.isFavorite.toggle()
        HapticFeedback.selection.trigger()
        touch()
    }

    private func link(_ recording: Recording, to sectionId: UUID?) {
        recording.linkedSectionId = sectionId
        touch()
    }

    private func rename(_ recording: Recording) {
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        recording.name = trimmed
        touch()
    }

    private func deleteRecording(_ recording: Recording) {
        if player.isLoaded(recording) {
            player.stop()
        }
        let url = FileManagerUtils.recordingURL(for: recording.fileName)
        try? FileManager.default.removeItem(at: url)

        if let index = project.recordings.firstIndex(where: { $0.id == recording.id }) {
            let removed = project.recordings.remove(at: index)
            modelContext.delete(removed)
        }
        HapticFeedback.warning.trigger()
        touch()
    }
}

// MARK: - Hero

/// The capture card: one big red button that starts recording immediately
/// with the remembered setup, plus quick toggles for that setup.
private struct RecordHeroCard: View {
    let takeNumber: Int
    let type: RecordingType
    @Binding var countInBars: Int
    @Binding var clickEnabled: Bool
    let onSelectType: (RecordingType) -> Void
    let onRecord: () -> Void
    let onMoreOptions: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(alignment: .center, spacing: DesignSystem.Spacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Take \(takeNumber)").eyebrow()
                    Text("Capture an idea")
                        .font(DesignSystem.Typography.title2)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Text(countInBars == 0 ? "Starts the moment you tap." : "Counts you in, then rolls.")
                        .font(DesignSystem.Typography.italicSmall)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
                Spacer(minLength: 0)
                RecordBigButton(state: .idle, size: 72, action: onRecord)
            }

            Hairline()

            HStack(spacing: DesignSystem.Spacing.xs) {
                Menu {
                    Picker("Type", selection: Binding(get: { type }, set: onSelectType)) {
                        ForEach(RecordingType.allCases, id: \.self) { type in
                            Label(type.recordDisplayName, systemImage: type.icon).tag(type)
                        }
                    }
                } label: {
                    optionLabel(icon: type.icon, text: type.recordDisplayName, isOn: true)
                }
                .accessibilityLabel("Recording type, \(type.recordDisplayName)")

                Menu {
                    Picker("Count-in", selection: $countInBars) {
                        Text("No count-in").tag(0)
                        Text("1 bar").tag(1)
                        Text("2 bars").tag(2)
                    }
                } label: {
                    optionLabel(icon: "timer", text: countInBars == 0 ? String(localized: "No count-in") : String(localized: "\(countInBars) bars"), isOn: countInBars > 0)
                }
                .accessibilityLabel("Count-in, \(countInBars == 0 ? String(localized: "off") : String(localized: "\(countInBars) bars"))")

                Button {
                    HapticFeedback.selection.trigger()
                    clickEnabled.toggle()
                } label: {
                    optionLabel(icon: "metronome", text: String(localized: "Click"), isOn: clickEnabled)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Click while recording")
                .accessibilityValue(clickEnabled ? "On" : "Off")

                Spacer(minLength: 0)

                Button(action: onMoreOptions) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("More recording options")
            }
        }
        .padding(DesignSystem.Spacing.md)
        .cardStyle()
    }

    private func optionLabel(icon: String, text: String, isOn: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(DesignSystem.Typography.buttonSmall)
                .lineLimit(1)
        }
        .foregroundStyle(isOn ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textTertiary)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Capsule().fill(isOn ? DesignSystem.Colors.surfaceSecondary : Color.clear))
        .overlay(Capsule().stroke(DesignSystem.Colors.border, lineWidth: 1))
    }
}

// MARK: - Row styling

private extension View {
    func rowStyle(top: CGFloat, bottom: CGFloat) -> some View {
        self
            .listRowInsets(EdgeInsets(
                top: top,
                leading: DesignSystem.Spacing.gutter,
                bottom: bottom,
                trailing: DesignSystem.Spacing.gutter
            ))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Project.self, configurations: config)
    let project = Project(title: "Test", bpm: 120)
    container.mainContext.insert(project)

    return RecordingsTabView(project: project)
        .modelContainer(container)
        .environmentObject(StudioPlaybackEngine())
}
