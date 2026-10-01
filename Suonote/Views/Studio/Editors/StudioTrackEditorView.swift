import SwiftUI
import SwiftData

// MARK: - Track editor
/// One full-screen editor for every kind of track, with the same grammar:
/// glass toolbar (close · Notes/Sound/Feel · more), a slim track header, the
/// tab's content, and the shared floating transport at the bottom.
struct StudioTrackEditorView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case notes, sound, feel
        var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var project: Project
    @Bindable var track: StudioTrack
    let totalBars: Int
    let beatsPerBar: Int
    let timeBottom: Int
    let style: StudioStyle?
    @ObservedObject var playback: StudioPlaybackEngine
    let onNotesChanged: () -> Void
    var onDelete: ((StudioTrack) -> Void)? = nil

    @State private var tab: Tab = .notes
    @State private var renameText = ""
    @State private var showingRename = false
    @State private var showingClearConfirm = false
    @State private var showingDeleteConfirm = false

    private var isAudio: Bool { track.instrument.isAudio }
    private var isDrums: Bool { track.instrument == .drums }

    private var tabs: [Tab] { isAudio ? [.notes, .sound] : Tab.allCases }

    private func title(for tab: Tab) -> String {
        switch tab {
        case .notes: return isAudio ? String(localized: "Clip") : (isDrums ? String(localized: "Groove") : String(localized: "Notes"))
        case .sound: return isAudio ? String(localized: "Mix") : String(localized: "Sound")
        case .feel: return String(localized: "Feel")
        }
    }

    private var barSectionInfos: [StudioBarSectionInfo] {
        project.studioBarSectionInfos(fallbackColor: track.instrument.color)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                trackHeader
                    .padding(.horizontal, DesignSystem.Spacing.gutter)
                    .padding(.top, DesignSystem.Spacing.xs)
                    .padding(.bottom, DesignSystem.Spacing.sm)
                Hairline()
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(DesignSystem.Colors.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if project.studioHasSections {
                    StudioFloatingTransport(project: project)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.bottom, DesignSystem.Spacing.xs)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
        .environmentObject(playback)
        .alert("Rename track", isPresented: $showingRename) {
            TextField("Track name", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                track.name = trimmed
                project.updatedAt = Date()
                try? modelContext.save()
            }
        }
        .confirmationDialog("Clear every note on \(track.name)?", isPresented: $showingClearConfirm, titleVisibility: .visible) {
            Button("Clear notes", role: .destructive, action: clearNotes)
        } message: {
            Text("You can write them again or use Feel → Rewrite part.")
        }
        .confirmationDialog("Delete \(track.name)?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Delete track", role: .destructive) {
                let target = track
                dismiss()
                onDelete?(target)
            }
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
            }
            .accessibilityLabel("Close editor")
        }

        ToolbarItem(placement: .principal) {
            Picker("Editor section", selection: $tab) {
                ForEach(tabs) { option in
                    Text(title(for: option)).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 260)
        }

        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button {
                    renameText = track.name
                    showingRename = true
                } label: {
                    Label("Rename", systemImage: "character.cursor.ibeam")
                }
                if !isAudio {
                    Button(role: .destructive) {
                        showingClearConfirm = true
                    } label: {
                        Label("Clear notes", systemImage: "eraser")
                    }
                }
                if onDelete != nil {
                    Divider()
                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Label("Delete track", systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
            }
            .accessibilityLabel("More")
        }
    }

    // MARK: Header

    private var trackHeader: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            StudioInstrumentBadge(instrument: track.instrument, size: 40)
            VStack(alignment: .leading, spacing: 1) {
                Text(track.name)
                    .font(DesignSystem.Typography.title2)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .lineLimit(1)
                Text(headerSubtitle)
                    .font(DesignSystem.Typography.italicSmall)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(StudioMusic.keyLabel(root: project.keyRoot, mode: project.keyMode)) · \(project.bpm)")
                    .font(DesignSystem.Typography.chordSmall)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                StudioLevelMeter(
                    level: playback.trackLevels[track.id] ?? 0,
                    isActive: playback.isPlaying && !track.isMuted
                )
                .frame(width: 56)
            }
        }
    }

    private var headerSubtitle: String {
        if isAudio { return String(localized: "Recording on the timeline") }
        var parts = [track.studioSoundName]
        if track.isMuted { parts.append(String(localized: "muted")) } else if track.isSolo { parts.append(String(localized: "solo")) }
        return parts.joined(separator: " · ")
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .notes:
            if isAudio {
                ScrollView {
                    StudioAudioTrackView(track: track, project: project, onChange: onNotesChanged)
                        .padding(DesignSystem.Spacing.gutter)
                }
            } else if isDrums {
                StudioDrumEditor(
                    track: track,
                    beatsPerBar: beatsPerBar,
                    timeBottom: timeBottom,
                    totalBars: totalBars,
                    barSectionInfos: barSectionInfos,
                    style: style,
                    onNotesChanged: onNotesChanged
                )
            } else {
                StudioNoteEditor(
                    track: track,
                    beatsPerBar: beatsPerBar,
                    timeBottom: timeBottom,
                    totalBars: totalBars,
                    barSectionInfos: barSectionInfos,
                    style: style,
                    onNotesChanged: onNotesChanged
                )
            }
        case .sound:
            StudioSoundPanel(project: project, track: track, style: style, onNotesChanged: onNotesChanged)
        case .feel:
            StudioFeelPanel(project: project, track: track, style: style, onNotesChanged: onNotesChanged)
        }
    }

    private func clearNotes() {
        for note in track.notes {
            modelContext.delete(note)
        }
        track.notes.removeAll()
        project.updatedAt = Date()
        try? modelContext.save()
        onNotesChanged()
        haptic(.light)
    }
}
