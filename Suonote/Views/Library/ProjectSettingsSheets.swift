import SwiftUI
import SwiftData

// MARK: - Edit Project Sheet
/// "Song details": title, status, tempo, meter, key and tags.
/// Changes are staged and applied on "Save changes"; structural changes
/// (tempo/key/meter on a song with an arrangement) ask for confirmation.
struct EditProjectSheet: View {
    @Bindable var project: Project
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allProjects: [Project]

    @State private var tempTitle: String = ""
    @State private var tempBPM: Int = 120
    @State private var tempTimeTop: Int = 4
    @State private var tempTimeBottom: Int = 4
    @State private var tempKeyRoot: String = "C"
    @State private var tempKeyMode: KeyMode = .major
    @State private var tempTags: [String] = []
    @State private var tempStatus: ProjectStatus = .idea
    @State private var didLoad = false
    @State private var showingProjectChangeWarning = false

    private var timeSignatureChanged: Bool {
        tempTimeTop != project.timeTop || tempTimeBottom != project.timeBottom
    }

    private var bpmChanged: Bool { tempBPM != project.bpm }

    private var keyChanged: Bool {
        tempKeyRoot != project.keyRoot || tempKeyMode != project.keyMode
    }

    private var shouldWarnAboutStructure: Bool {
        (timeSignatureChanged || bpmChanged || keyChanged) && !project.arrangementItems.isEmpty
    }

    private var tagSuggestions: [String] {
        Array(Set(allProjects.flatMap(\.tags))).sorted()
    }

    var body: some View {
        SheetScaffold(
            title: String(localized: "Song details"),
            subtitle: String(localized: "Key, tempo and the rest of the paperwork."),
            primaryTitle: String(localized: "Save changes"),
            primaryIcon: "checkmark",
            primaryAction: attemptSave
        ) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                LibraryFormGroup(title: String(localized: "Title")) {
                    TextField("Song title", text: $tempTitle, axis: .vertical)
                        .font(DesignSystem.Typography.title2)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .lineLimit(1...3)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                        .wellStyle()
                }

                LibraryFormGroup(title: String(localized: "Status")) {
                    LibraryStatusChips(status: $tempStatus)
                }

                LibraryFormGroup(title: String(localized: "Tempo")) {
                    BPMSelector(bpm: $tempBPM, timeTop: tempTimeTop, timeBottom: tempTimeBottom)
                }

                LibraryFormGroup(title: String(localized: "Meter")) {
                    LibraryMeterPicker(top: $tempTimeTop, bottom: $tempTimeBottom)
                }

                LibraryFormGroup(title: String(localized: "Key"), detail: "\(tempKeyRoot) \(tempKeyMode.libraryDisplayName.lowercased())") {
                    LibraryKeyPicker(root: $tempKeyRoot, mode: $tempKeyMode)
                    if keyChanged && tempKeyRoot != project.keyRoot && !project.arrangementItems.isEmpty {
                        Label("Chords will be transposed to the new key.", systemImage: "arrow.up.arrow.down")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                }

                LibraryFormGroup(title: String(localized: "Tags")) {
                    LibraryTagEditor(tags: $tempTags, suggestions: tagSuggestions)
                }
            }
        }
        .presentationDetents([.large])
        .alert("Update song settings?", isPresented: $showingProjectChangeWarning) {
            Button("Cancel", role: .cancel) {}
            Button("Apply changes") { saveChanges() }
        } message: {
            Text("Changing tempo, key or meter updates your sections and regenerates Studio parts.")
        }
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            loadCurrentValues()
        }
    }

    private func attemptSave() {
        if shouldWarnAboutStructure {
            showingProjectChangeWarning = true
        } else {
            saveChanges()
        }
    }

    private func loadCurrentValues() {
        tempTitle = project.title
        tempBPM = project.bpm
        let signature = TimeSignaturePreset.from(top: project.timeTop, bottom: project.timeBottom)
        tempTimeTop = signature.top
        tempTimeBottom = signature.bottom
        tempKeyRoot = project.keyRoot
        tempKeyMode = project.keyMode == .aeolian ? .minor : project.keyMode
        tempTags = project.tags
        tempStatus = project.status
    }

    private func saveChanges() {
        let oldTimeTop = project.timeTop
        let oldTimeBottom = project.timeBottom
        let oldKeyRoot = project.keyRoot
        let shouldReflow = tempTimeTop != oldTimeTop || tempTimeBottom != oldTimeBottom
        let cleanTitle = tempTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        project.title = cleanTitle.isEmpty ? project.title : cleanTitle
        project.bpm = tempBPM
        project.timeTop = tempTimeTop
        project.timeBottom = tempTimeBottom
        project.keyRoot = tempKeyRoot
        project.keyMode = tempKeyMode
        project.tags = tempTags
        project.status = tempStatus
        if oldKeyRoot != tempKeyRoot {
            project.applyKeyChange(oldRoot: oldKeyRoot, newRoot: tempKeyRoot)
        }
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
        HapticFeedback.success.trigger()
        dismiss()
    }
}

// MARK: - Status Picker Sheet

struct StatusPickerSheet: View {
    @Bindable var project: Project
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        SheetScaffold(title: String(localized: "Status"), subtitle: String(localized: "Where is this song at?")) {
            VStack(spacing: 0) {
                ForEach(Array(ProjectStatus.allCases.enumerated()), id: \.element) { index, status in
                    if index > 0 {
                        Hairline().padding(.leading, 52)
                    }
                    row(status)
                }
            }
            .cardStyle()
        }
        .presentationDetents([.medium, .large])
    }

    private func row(_ status: ProjectStatus) -> some View {
        let isCurrent = project.status == status
        return Button {
            updateStatus(to: status)
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(status.swiftUIColor.opacity(0.14))
                        .frame(width: 32, height: 32)
                    Image(systemName: status.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(status.swiftUIColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(status.libraryDisplayName)
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Text(status.libraryBlurb)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if isCurrent {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.primaryDark)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

    private func updateStatus(to status: ProjectStatus) {
        HapticFeedback.selection.trigger()
        withAnimation(DesignSystem.Animations.quickSpring) {
            project.status = status
            project.updatedAt = Date()
        }
        try? modelContext.save()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { dismiss() }
    }
}
