import Foundation
import SwiftData
import SwiftUI

// MARK: - Project Snapshot (W2)
// Stores a point-in-time snapshot of a project's composition state.
// Lightweight: stores chord data + section structure as JSON.

@Model
final class ProjectSnapshot {
    var id: UUID = UUID()
    var name: String = "Snapshot"
    var createdAt: Date = Date()
    var note: String = ""

    // Serialized project state
    var keyRoot: String = "C"
    var keyModeRaw: String = KeyMode.major.rawValue
    var bpm: Int = 120
    var sectionDataJSON: String = ""    // JSON-encoded [SnapshotSection]
    var arrangementJSON: String = ""    // JSON-encoded section order

    var projectStore: Project?

    var project: Project? {
        get { projectStore }
        set { projectStore = newValue }
    }

    var keyMode: KeyMode {
        KeyMode(rawValue: keyModeRaw) ?? .major
    }
}

// MARK: - Lightweight snapshot data types

struct SnapshotSection: Codable {
    let id: UUID
    let name: String
    let bars: Int
    let colorHex: String
    let lyricsText: String
    let chords: [SnapshotChord]
}

struct SnapshotChord: Codable {
    let barIndex: Int
    let beatOffset: Double
    let duration: Double
    let isRest: Bool
    let root: String
    let quality: String
    let extensions: [String]
    let slashRoot: String?
}

// MARK: - Snapshot Engine

struct ProjectSnapshotEngine {

    /// Create a snapshot from the current state of a project
    static func createSnapshot(for project: Project, name: String, note: String = "") -> ProjectSnapshot {
        let snapshot = ProjectSnapshot()
        snapshot.name = name.isEmpty ? "Snapshot \(dateString())" : name
        snapshot.note = note
        snapshot.keyRoot = project.keyRoot
        snapshot.keyModeRaw = project.keyMode.rawValue
        snapshot.bpm = project.bpm

        // Encode sections
        let sections = project.sectionTemplates.map { section -> SnapshotSection in
            let chords = section.chordEvents.map { chord -> SnapshotChord in
                SnapshotChord(
                    barIndex: chord.barIndex,
                    beatOffset: chord.beatOffset,
                    duration: chord.duration,
                    isRest: chord.isRest,
                    root: chord.root,
                    quality: chord.quality.rawValue,
                    extensions: chord.extensions,
                    slashRoot: chord.slashRoot
                )
            }
            return SnapshotSection(
                id: section.id,
                name: section.name,
                bars: section.bars,
                colorHex: section.colorHex ?? "#6B7B6B",
                lyricsText: section.lyricsText,
                chords: chords
            )
        }

        if let data = try? JSONEncoder().encode(sections) {
            snapshot.sectionDataJSON = String(data: data, encoding: .utf8) ?? ""
        }

        // Encode arrangement order
        let order = project.arrangementItems
            .sorted { $0.orderIndex < $1.orderIndex }
            .compactMap { $0.sectionTemplate?.id.uuidString }
        if let orderData = try? JSONEncoder().encode(order) {
            snapshot.arrangementJSON = String(data: orderData, encoding: .utf8) ?? ""
        }

        return snapshot
    }

    /// Get decoded sections from a snapshot
    static func decodeSections(from snapshot: ProjectSnapshot) -> [SnapshotSection] {
        guard let data = snapshot.sectionDataJSON.data(using: .utf8),
              let sections = try? JSONDecoder().decode([SnapshotSection].self, from: data) else {
            return []
        }
        return sections
    }

    /// Format a readable summary of a snapshot
    static func summary(for snapshot: ProjectSnapshot) -> String {
        let sections = decodeSections(from: snapshot)
        let totalChords = sections.map { $0.chords.filter { !$0.isRest }.count }.reduce(0, +)
        let totalBars = sections.map { $0.bars }.reduce(0, +)
        return "\(sections.count) sections · \(totalBars) bars · \(totalChords) chords · \(snapshot.keyRoot) \(snapshot.keyMode.rawValue)"
    }

    private static func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d HH:mm"
        return formatter.string(from: Date())
    }
}

// MARK: - Snapshots View (W2)

struct ProjectSnapshotsView: View {
    let project: Project
    @Environment(\.modelContext) private var modelContext
    @State private var snapshots: [ProjectSnapshot] = []
    @State private var showCreateSheet = false
    @State private var newSnapshotName = ""
    @State private var newSnapshotNote = ""
    @State private var selectedSnapshot: ProjectSnapshot? = nil
    @State private var showDiffView = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if snapshots.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(snapshots.sorted { $0.createdAt > $1.createdAt }) { snapshot in
                            snapshotRow(snapshot)
                        }
                        .onDelete { indexSet in
                            for idx in indexSet {
                                let sorted = snapshots.sorted { $0.createdAt > $1.createdAt }
                                modelContext.delete(sorted[idx])
                            }
                            loadSnapshots()
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Version Snapshots")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        newSnapshotName = ""
                        newSnapshotNote = ""
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "camera.badge.clock")
                            .foregroundStyle(DesignSystem.Colors.primary)
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                createSnapshotSheet
            }
            .sheet(item: $selectedSnapshot) { snapshot in
                snapshotDetailView(snapshot)
            }
            .onAppear { loadSnapshots() }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Spacer()
            Image(systemName: "camera.badge.clock")
                .font(.system(size: 48))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
            Text("No snapshots yet")
                .font(DesignSystem.Typography.title3)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            Text("Tap the camera icon to save the current state of your project. You can compare and review any previous version.")
                .font(DesignSystem.Typography.callout)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.xxl)
            Spacer()
        }
    }

    // MARK: - Snapshot Row

    private func snapshotRow(_ snapshot: ProjectSnapshot) -> some View {
        Button { selectedSnapshot = snapshot } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(snapshot.name)
                        .font(DesignSystem.Typography.bodyBold)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Spacer()
                    Text(relativeDate(snapshot.createdAt))
                        .font(DesignSystem.Typography.caption2)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }

                Text(ProjectSnapshotEngine.summary(for: snapshot))
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)

                if !snapshot.note.isEmpty {
                    Text(snapshot.note)
                        .font(DesignSystem.Typography.callout)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .lineLimit(2)
                        .italic()
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Create Sheet

    private var createSnapshotSheet: some View {
        NavigationStack {
            Form {
                Section("Snapshot Name") {
                    TextField("e.g. 'Before bridge rewrite'", text: $newSnapshotName)
                }
                Section("Note (optional)") {
                    TextField("What changed? What are you trying?", text: $newSnapshotNote)
                }
                Section("Current State") {
                    let sections = project.sectionTemplates
                    Text("\(sections.count) sections · \(sections.map { $0.bars }.reduce(0, +)) total bars")
                        .font(DesignSystem.Typography.callout)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                    Text("\(project.keyRoot) \(project.keyMode.rawValue) · \(project.bpm) BPM")
                        .font(DesignSystem.Typography.callout)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
            .navigationTitle("Save Snapshot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showCreateSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let snapshot = ProjectSnapshotEngine.createSnapshot(
                            for: project,
                            name: newSnapshotName,
                            note: newSnapshotNote
                        )
                        snapshot.project = project
                        modelContext.insert(snapshot)
                        try? modelContext.save()
                        loadSnapshots()
                        showCreateSheet = false
                        HapticFeedback.success()
                    }
                }
            }
        }
    }

    // MARK: - Snapshot Detail

    private func snapshotDetailView(_ snapshot: ProjectSnapshot) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {

                    // Meta
                    Group {
                        LabeledContent("Key", value: "\(snapshot.keyRoot) \(snapshot.keyMode.rawValue)")
                        LabeledContent("BPM", value: "\(snapshot.bpm)")
                        LabeledContent("Saved", value: snapshot.createdAt.formatted(date: .abbreviated, time: .shortened))
                    }
                    .font(DesignSystem.Typography.callout)
                    .padding(.horizontal, DesignSystem.Spacing.md)

                    Divider().overlay(DesignSystem.Colors.border)

                    // Sections
                    let sections = ProjectSnapshotEngine.decodeSections(from: snapshot)
                    ForEach(sections, id: \.id) { section in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(section.name)
                                    .font(DesignSystem.Typography.bodyBold)
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                                Spacer()
                                Text("\(section.bars) bars · \(section.chords.filter { !$0.isRest }.count) chords")
                                    .font(DesignSystem.Typography.caption2)
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                            }

                            // Chord display
                            let chordNames = section.chords.filter { !$0.isRest }.prefix(8)
                                .map { $0.root + $0.quality }
                            if !chordNames.isEmpty {
                                Text(chordNames.joined(separator: " · "))
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundStyle(DesignSystem.Colors.primary)
                            }

                            if !section.lyricsText.isEmpty {
                                Text(section.lyricsText)
                                    .font(DesignSystem.Typography.callout)
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(DesignSystem.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                .fill(DesignSystem.Colors.surfaceSecondary)
                        )
                        .padding(.horizontal, DesignSystem.Spacing.md)
                    }
                }
                .padding(.vertical, DesignSystem.Spacing.md)
            }
            .navigationTitle(snapshot.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { selectedSnapshot = nil }
                }
            }
        }
    }

    // MARK: - Helpers

    private func loadSnapshots() {
        let descriptor = FetchDescriptor<ProjectSnapshot>()
        let all = (try? modelContext.fetch(descriptor)) ?? []
        snapshots = all.filter { $0.project?.id == project.id }
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
