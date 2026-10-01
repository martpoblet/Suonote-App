import SwiftUI

// MARK: - Recording Type Picker Sheet

/// Choose what a take is (voice, guitar, idea…). Selecting dismisses.
struct RecordingTypePickerSheet: View {
    @Binding var selectedType: RecordingType
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.flexible(), spacing: DesignSystem.Spacing.sm),
                           GridItem(.flexible(), spacing: DesignSystem.Spacing.sm)]

    var body: some View {
        SheetScaffold(title: String(localized: "Recording type"), subtitle: String(localized: "What are you capturing?")) {
            LazyVGrid(columns: columns, spacing: DesignSystem.Spacing.sm) {
                ForEach(RecordingType.allCases, id: \.self) { type in
                    RecordTypeTile(type: type, isSelected: selectedType == type) {
                        HapticFeedback.selection.trigger()
                        selectedType = type
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .studioModalStyle()
    }
}

private struct RecordTypeTile: View {
    let type: RecordingType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(isSelected ? DesignSystem.Colors.background.opacity(0.18) : type.color.opacity(0.18))
                        .frame(width: 36, height: 36)
                    Image(systemName: type.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isSelected ? DesignSystem.Colors.background : DesignSystem.Colors.textPrimary)
                }
                Text(type.recordDisplayName)
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundStyle(isSelected ? DesignSystem.Colors.background : DesignSystem.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.background)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                    .fill(isSelected ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                    .stroke(isSelected ? Color.clear : DesignSystem.Colors.border, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(type.recordDisplayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Section Link Sheet

/// Link a take to one of the song's sections (or remove the link).
struct SectionLinkSheet: View {
    @Bindable var recording: Recording
    let sections: [SectionTemplate]
    let onLink: (UUID?) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SheetScaffold(title: String(localized: "Link to section"), subtitle: recording.name) {
            if sections.isEmpty {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    BrandWavesMark(size: 28)
                    Text("No sections yet")
                        .font(DesignSystem.Typography.title3)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Text("Add sections in Compose, then link takes to them.")
                        .font(DesignSystem.Typography.italicSmall)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.xxl)
            } else {
                VStack(spacing: 0) {
                    row(title: String(localized: "No section"), detail: String(localized: "Keep it as a loose idea"), color: nil,
                        isSelected: recording.linkedSectionId == nil) {
                        select(nil)
                    }
                    ForEach(sections) { section in
                        Hairline().padding(.leading, 44)
                        row(title: section.name, detail: String(localized: "\(section.bars) bars"), color: section.color,
                            isSelected: recording.linkedSectionId == section.id) {
                            select(section.id)
                        }
                    }
                }
                .cardStyle()
            }
        }
        .presentationDetents([.medium, .large])
        .studioModalStyle()
    }

    private func select(_ id: UUID?) {
        HapticFeedback.selection.trigger()
        onLink(id)
        dismiss()
    }

    private func row(title: String, detail: String, color: Color?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Group {
                    if let color {
                        SectionColorDot(color, size: 10)
                    } else {
                        Image(systemName: "circle.dashed")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }
                }
                .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(color == nil ? DesignSystem.Typography.subheadline : DesignSystem.Typography.headline)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Text(detail)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.primaryDark)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
