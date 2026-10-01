import SwiftUI
import os
import SwiftData

/// "New song" sheet: name it, pick a shape and a tempo, go.
/// Everything except the title is optional; key, status and tags live
/// under "More details" so the fast path is two taps.
struct CreateProjectView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Project.updatedAt, order: .reverse) private var existingProjects: [Project]

    /// Called with the freshly inserted song so the caller can open it.
    var onCreated: ((Project) -> Void)? = nil

    @State private var title = ""
    @State private var starter: LibraryStarter = .all[1]
    @State private var bpm = 100
    @State private var timeTop = 4
    @State private var timeBottom = 4
    @State private var keyRoot = "C"
    @State private var keyMode: KeyMode = .major
    @State private var status: ProjectStatus = .idea
    @State private var tags: [String] = []
    @State private var showsMore = false
    @FocusState private var titleFocused: Bool

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var tagSuggestions: [String] {
        var counts: [String: Int] = [:]
        for project in existingProjects { for tag in project.tags { counts[tag, default: 0] += 1 } }
        return counts.sorted { $0.value > $1.value }.map(\.key)
    }

    var body: some View {
        SheetScaffold(
            title: String(localized: "New song"),
            subtitle: String(localized: "Name it now, or let it find its name."),
            primaryTitle: String(localized: "Create song"),
            primaryIcon: "arrow.right",
            primaryAction: createProject
        ) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                titleField
                structurePicker
                LibraryFormGroup(title: String(localized: "Tempo")) {
                    BPMSelector(bpm: $bpm, timeTop: timeTop, timeBottom: timeBottom)
                }
                LibraryFormGroup(title: String(localized: "Meter")) {
                    LibraryMeterPicker(top: $timeTop, bottom: $timeBottom)
                }
                moreDetails
            }
        }
        .presentationDetents([.large])
        .studioModalStyle()
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { titleFocused = true }
        }
    }

    // MARK: Title

    private var titleField: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            TextField(
                "",
                text: $title,
                prompt: Text("Untitled sketch").foregroundStyle(DesignSystem.Colors.textMuted),
                axis: .vertical
            )
            .font(DesignSystem.Typography.largeTitle)
            .foregroundStyle(DesignSystem.Colors.textPrimary)
            .lineLimit(1...3)
            .focused($titleFocused)
            .submitLabel(.done)
            .onChange(of: title) { _, newValue in
                // Vertical-axis fields insert newlines on return; treat it as "done".
                if newValue.contains("\n") {
                    title = newValue.replacingOccurrences(of: "\n", with: "")
                    titleFocused = false
                }
            }
            .accessibilityLabel("Song title")

            Hairline(color: titleFocused ? DesignSystem.Colors.primary : DesignSystem.Colors.borderActive)
                .animation(DesignSystem.Animations.quickEase, value: titleFocused)
        }
        .padding(.top, DesignSystem.Spacing.xs)
    }

    // MARK: Structure

    private var structurePicker: some View {
        LibraryFormGroup(title: String(localized: "Start from"), detail: starter.parts.isEmpty ? nil : String(localized: "\(starter.uniqueSectionCount) sections · \(starter.totalBars) bars")) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(LibraryStarter.all) { option in
                        starterCard(option)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
        }
    }

    private func starterCard(_ option: LibraryStarter) -> some View {
        let selected = option == starter
        return Button {
            HapticFeedback.selection.trigger()
            withAnimation(DesignSystem.Animations.quickSpring) { starter = option }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text(option.name)
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .lineLimit(1)
                Text(option.detail)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                LibraryArrangementStrip(starter: option, height: 4)
            }
            .padding(DesignSystem.Spacing.sm)
            .frame(width: 168, height: 104, alignment: .topLeading)
            .cardStyle(
                cornerRadius: DesignSystem.CornerRadius.md,
                color: selected ? DesignSystem.Colors.textPrimary : nil,
                fill: selected ? DesignSystem.Colors.surface : DesignSystem.Colors.backgroundSecondary
            )
            .overlay(alignment: .topTrailing) {
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(DesignSystem.Colors.primaryDark)
                        .padding(8)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(option.name), \(option.detail)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: More

    private var moreDetails: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Button {
                withAnimation(DesignSystem.Animations.smoothSpring) { showsMore.toggle() }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("More details")
                            .font(DesignSystem.Typography.headline)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                        Text(moreDetailsSummary)
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .rotationEffect(.degrees(showsMore ? 180 : 0))
                }
                .padding(DesignSystem.Spacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .cardStyle()
            .accessibilityHint(showsMore ? "Hides key, status and tags" : "Shows key, status and tags")

            if showsMore {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                    LibraryFormGroup(title: String(localized: "Key")) {
                        LibraryKeyPicker(root: $keyRoot, mode: $keyMode)
                    }
                    LibraryFormGroup(title: String(localized: "Status")) {
                        LibraryStatusChips(status: $status, includeArchived: false)
                    }
                    LibraryFormGroup(title: String(localized: "Tags")) {
                        LibraryTagEditor(tags: $tags, suggestions: tagSuggestions)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var moreDetailsSummary: String {
        let base = "\(keyRoot) \(keyMode.libraryDisplayName.lowercased()) · \(status.libraryDisplayName)"
        return tags.isEmpty ? base : "\(base) · \(String(localized: "\(tags.count) tags"))"
    }

    // MARK: Create

    private func createProject() {
        let project = Project(
            title: trimmedTitle.isEmpty ? String(localized: "Untitled sketch") : trimmedTitle,
            status: status,
            tags: tags,
            keyRoot: keyRoot,
            keyMode: keyMode,
            bpm: bpm,
            timeTop: timeTop,
            timeBottom: timeBottom
        )
        modelContext.insert(project)
        starter.apply(to: project)
        project.updatedAt = Date()

        do {
            try modelContext.save()
            AppLog.general.info("Created song: \(project.title, privacy: .private)")
        } catch {
            AppLog.general.error("Failed to save new song: \(error.localizedDescription)")
        }
        HapticFeedback.success.trigger()
        dismiss()
        if let onCreated {
            // Let the sheet start dismissing before pushing the song.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onCreated(project) }
        }
    }
}

#Preview {
    CreateProjectView()
        .modelContainer(for: [Project.self], inMemory: true)
}
