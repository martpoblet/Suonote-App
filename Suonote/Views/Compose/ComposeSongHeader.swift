import SwiftUI
import SwiftData

// MARK: - Song facts header
/// Eyebrow + undo/redo/export, then Key · Tempo · Meter set as Erode figures.
/// Each figure is a button that opens its editor.
struct ComposeSongHeader: View {
    @Bindable var project: Project
    let items: [ArrangementItem]
    let onKey: () -> Void
    let onTempo: () -> Void
    let onExport: () -> Void
    @Environment(ComposeEditor.self) private var editor

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Text("Lead sheet")
                    .eyebrow()
                Spacer(minLength: 0)
                ComposeIconButton(systemImage: "arrow.uturn.backward", label: undoLabel, isEnabled: editor.history.canUndo) {
                    editor.undo()
                }
                .keyboardShortcut("z", modifiers: .command)
                ComposeIconButton(systemImage: "arrow.uturn.forward", label: redoLabel, isEnabled: editor.history.canRedo) {
                    editor.redo()
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                ComposeIconButton(systemImage: "square.and.arrow.up", label: String(localized: "Export lead sheet"), isEnabled: true) {
                    haptic(.light)
                    onExport()
                }
            }

            HStack(alignment: .top, spacing: 0) {
                fact(
                    label: String(localized: "Key"),
                    value: ComposeFormat.keyShort(root: project.keyRoot, mode: project.keyMode),
                    accessibilityValue: ComposeFormat.keyName(root: project.keyRoot, mode: project.keyMode),
                    action: onKey
                )
                divider
                fact(label: String(localized: "Tempo"), value: "\(project.bpm)", unit: "bpm", accessibilityValue: String(localized: "\(project.bpm) beats per minute"), action: onTempo)
                divider
                fact(label: String(localized: "Meter"), value: "\(project.timeTop)/\(project.timeBottom)", accessibilityValue: "\(project.timeTop) \(project.timeBottom)", action: onTempo)
            }

            if !items.isEmpty {
                Text(summary)
                    .font(DesignSystem.Typography.italicSmall)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
        }
    }

    private var undoLabel: String {
        editor.history.canUndo ? String(localized: "Undo \(editor.history.undoLabel.lowercased())") : String(localized: "Undo")
    }

    private var redoLabel: String {
        editor.history.canRedo ? String(localized: "Redo \(editor.history.redoLabel.lowercased())") : String(localized: "Redo")
    }

    private var summary: String {
        let bars = items.reduce(0) { $0 + max(1, $1.sectionTemplate?.bars ?? 0) }
        let seconds = Double(bars * project.timeTop) * project.gridBeatInterval()
        return String(localized: "\(items.count) sections · \(bars) bars · about \(ComposeFormat.clock(seconds))")
    }

    private var divider: some View {
        Rectangle()
            .fill(DesignSystem.Colors.border)
            .frame(width: 1)
            .padding(.vertical, 4)
            .padding(.horizontal, DesignSystem.Spacing.md)
    }

    private func fact(
        label: String,
        value: String,
        unit: String? = nil,
        accessibilityValue: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            haptic(.selection)
            action()
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .eyebrow()
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value)
                        .font(DesignSystem.Typography.title)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if let unit {
                        Text(unit)
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(AnimatedPressButtonStyle(scale: 0.96))
        .accessibilityLabel(label)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Double-tap to change")
    }
}

/// Small glass circle for header/section utilities.
struct ComposeIconButton: View {
    let systemImage: String
    let label: String
    var isEnabled: Bool = true
    var tint: Color = DesignSystem.Colors.textPrimary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isEnabled ? tint : DesignSystem.Colors.textMuted)
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .disabled(!isEnabled)
        .accessibilityLabel(label)
    }
}

// MARK: - Tempo & meter sheet

struct ComposeTempoMeterSheet: View {
    @Bindable var project: Project
    @Environment(\.dismiss) private var dismiss
    @Environment(ComposeEditor.self) private var editor

    @State private var bpm: Int = 120
    @State private var meter: TimeSignaturePreset = .fourFour
    @State private var tapTempo = TapTempo()

    private let bpmRange = 20...300

    var body: some View {
        SheetScaffold(
            title: String(localized: "Tempo & meter"),
            subtitle: TempoUtils.tempoDescription(for: bpm),
            primaryTitle: String(localized: "Apply"),
            primaryAction: apply
        ) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                tempoCard
                meterCard
            }
        }
        .onAppear {
            bpm = project.bpm
            meter = TimeSignaturePreset.from(top: project.timeTop, bottom: project.timeBottom)
        }
    }

    private var tempoCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            SectionHeader(title: String(localized: "Tempo"))
            HStack(alignment: .center, spacing: DesignSystem.Spacing.md) {
                stepButton("minus", delta: -1)
                Spacer(minLength: 0)
                VStack(spacing: 0) {
                    Text("\(bpm)")
                        .font(DesignSystem.Typography.display)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(bpm)))
                    Text("beats per minute")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
                Spacer(minLength: 0)
                stepButton("plus", delta: 1)
            }

            Slider(
                value: Binding(get: { Double(bpm) }, set: { bpm = Int($0.rounded()) }),
                in: 40...220
            )
            .tint(DesignSystem.Colors.primary)
            .accessibilityLabel("Tempo")
            .accessibilityValue("\(bpm) beats per minute")

            HStack(spacing: DesignSystem.Spacing.xs) {
                ForEach([70, 90, 110, 128], id: \.self) { preset in
                    SelectableChip(title: "\(preset)", isSelected: bpm == preset) {
                        haptic(.selection)
                        withAnimation(DesignSystem.Animations.quickSpring) { bpm = preset }
                    }
                }
                Spacer(minLength: 0)
                Button {
                    tapTempo.tap()
                    haptic(.light)
                    if tapTempo.currentBPM > 0 {
                        withAnimation(DesignSystem.Animations.quickSpring) { bpm = tapTempo.currentBPM }
                    }
                } label: {
                    Label("Tap", systemImage: "hand.tap")
                }
                .buttonStyle(InkButtonStyle(compact: true))
                .accessibilityHint("Tap repeatedly in time to set the tempo")
            }
        }
        .padding(DesignSystem.Spacing.md)
        .cardStyle()
    }

    private var meterCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            SectionHeader(title: String(localized: "Meter"))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DesignSystem.Spacing.xs), count: 3), spacing: DesignSystem.Spacing.xs) {
                ForEach(TimeSignaturePreset.allCases) { preset in
                    let selected = preset == meter
                    Button {
                        haptic(.selection)
                        meter = preset
                    } label: {
                        Text(preset.rawValue)
                            .font(DesignSystem.Typography.title3)
                            .foregroundStyle(selected ? DesignSystem.Colors.background : DesignSystem.Colors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignSystem.Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                                    .fill(selected ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.surfaceSecondary)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            if meter.top != project.timeTop || meter.bottom != project.timeBottom {
                Label("Chords will be re-flowed into the new bar length.", systemImage: "info.circle")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .cardStyle()
    }

    private func stepButton(_ icon: String, delta: Int) -> some View {
        Button {
            haptic(.selection)
            withAnimation(DesignSystem.Animations.quickSpring) {
                bpm = min(max(bpm + delta, bpmRange.lowerBound), bpmRange.upperBound)
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .buttonRepeatBehavior(.enabled)
        .accessibilityLabel(delta > 0 ? "Faster" : "Slower")
    }

    private func apply() {
        let oldTop = project.timeTop
        let oldBottom = project.timeBottom
        let newBpm = bpm
        let newMeter = meter
        editor.perform(String(localized: "Change tempo")) {
            project.bpm = newBpm
            if newMeter.top != oldTop || newMeter.bottom != oldBottom {
                project.timeTop = newMeter.top
                project.timeBottom = newMeter.bottom
                project.applyTimeSignatureChange(
                    oldTimeTop: oldTop,
                    oldTimeBottom: oldBottom,
                    newTimeTop: newMeter.top,
                    newTimeBottom: newMeter.bottom
                )
            }
        }
        haptic(.success)
        dismiss()
    }
}
