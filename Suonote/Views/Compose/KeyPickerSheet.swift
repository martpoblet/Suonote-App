import SwiftUI
import SwiftData

// MARK: - Key picker
/// Choose the song's key on the circle of fifths (or by note + mode),
/// hear its tonic chord, and optionally move every chord along with it.
struct KeyPickerSheet: View {
    @Bindable var project: Project
    let preview: ChordPreviewPlayer

    @Environment(\.dismiss) private var dismiss
    @Environment(ComposeEditor.self) private var editor

    @State private var root = "C"
    @State private var mode: KeyMode = .major
    @State private var transpose = true
    @State private var loaded = false

    private var changed: Bool {
        MusicTheory.normalize(root) != MusicTheory.normalize(project.keyRoot) || mode != project.keyMode
    }

    private var hasChords: Bool {
        project.sectionTemplates.contains { !$0.chordEvents.isEmpty }
    }

    private var rootChanged: Bool {
        MusicTheory.normalize(root) != MusicTheory.normalize(project.keyRoot)
    }

    var body: some View {
        SheetScaffold(
            title: String(localized: "Key"),
            subtitle: changed ? String(localized: "From \(ComposeFormat.keyName(root: project.keyRoot, mode: project.keyMode))") : String(localized: "The home your chords return to"),
            primaryTitle: changed ? String(localized: "Set \(ComposeFormat.keyName(root: root, mode: mode))") : String(localized: "Done"),
            primaryAction: apply
        ) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Text(ComposeFormat.keyName(root: root, mode: mode).capitalizedFirst)
                        .font(DesignSystem.Typography.largeTitle)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .contentTransition(.opacity)
                    Text(scaleLine)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity)

                CircleOfFifthsView(currentKey: root, currentMode: mode) { newRoot, newMode in
                    withAnimation(DesignSystem.Animations.quickSpring) {
                        root = newRoot
                        mode = newMode
                    }
                    playTonic()
                }
                .frame(maxWidth: 360)
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    SectionHeader(title: String(localized: "Tonic"))
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
                        ForEach(ComposeFormat.chromatic, id: \.self) { note in
                            let selected = MusicTheory.normalize(root) == note
                            Button {
                                haptic(.selection)
                                root = note
                                playTonic()
                            } label: {
                                Text(MusicTheory.displayName(for: note, inKey: note, mode: mode))
                                    .font(DesignSystem.Typography.chordSmall)
                                    .foregroundStyle(selected ? DesignSystem.Colors.background : DesignSystem.Colors.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 40)
                                    .background(
                                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm, style: .continuous)
                                            .fill(selected ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.surfaceSecondary)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(selected ? .isSelected : [])
                        }
                    }
                }

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    SectionHeader(title: String(localized: "Mode"))
                    ComposeFlowLayout(spacing: 6, lineSpacing: 6) {
                        ForEach(KeyMode.commonModes, id: \.self) { option in
                            SelectableChip(title: ComposeFormat.modeName(option), isSelected: mode == option) {
                                haptic(.selection)
                                mode = option
                                playTonic()
                            }
                        }
                        Menu {
                            ForEach(KeyMode.allCases.filter { !KeyMode.commonModes.contains($0) }, id: \.self) { option in
                                Button(ComposeFormat.modeName(option)) {
                                    mode = option
                                    playTonic()
                                }
                            }
                        } label: {
                            ComposeChipLabel(
                                title: KeyMode.commonModes.contains(mode) ? String(localized: "More modes") : ComposeFormat.modeName(mode),
                                isSelected: !KeyMode.commonModes.contains(mode)
                            )
                        }
                    }
                }

                if hasChords && rootChanged {
                    Toggle(isOn: $transpose) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Move chords to the new key")
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                            Text(transpose ? "Every chord shifts by the same interval." : "Chords stay as written; only the key changes.")
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }
                    }
                    .tint(DesignSystem.Colors.primary)
                    .padding(DesignSystem.Spacing.md)
                    .cardStyle()
                }
            }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            root = MusicTheory.normalize(project.keyRoot)
            mode = project.keyMode
        }
    }

    private var scaleLine: String {
        mode.intervals
            .map { MusicTheory.displayName(for: ChordSuggestionEngine.transpose(note: root, semitones: $0), inKey: root, mode: mode) }
            .joined(separator: " · ")
    }

    private func playTonic() {
        preview.playChord(root: root, quality: mode.isMinor ? .minor : .major)
    }

    private func apply() {
        guard changed else {
            dismiss()
            return
        }
        let oldRoot = project.keyRoot
        let newRoot = root
        let newMode = mode
        let shouldTranspose = transpose
        editor.perform(String(localized: "Change key"), toast: String(localized: "Key set to \(ComposeFormat.keyName(root: newRoot, mode: newMode))")) {
            project.keyRoot = newRoot
            project.keyMode = newMode
            if shouldTranspose, MusicTheory.normalize(oldRoot) != MusicTheory.normalize(newRoot) {
                project.applyKeyChange(oldRoot: oldRoot, newRoot: newRoot)
            }
        }
        haptic(.success)
        dismiss()
    }
}

/// Static look of `SelectableChip`, for use as a Menu label.
struct ComposeChipLabel: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(DesignSystem.Typography.buttonSmall)
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .bold))
        }
        .foregroundStyle(isSelected ? DesignSystem.Colors.background : DesignSystem.Colors.textPrimary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(isSelected ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.surface))
        .overlay(Capsule().stroke(isSelected ? Color.clear : DesignSystem.Colors.border, lineWidth: 1))
    }
}

private extension String {
    var capitalizedFirst: String {
        prefix(1).uppercased() + dropFirst()
    }
}
