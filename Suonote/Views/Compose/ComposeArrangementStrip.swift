import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Arrangement strip
/// The song's form at a glance: one segment per section, width proportional
/// to its bars. Tap to jump/focus, long-press and drag to reorder.
struct ComposeArrangementStrip: View {
    @Bindable var project: Project
    let items: [ArrangementItem]
    @Binding var focusedItemId: UUID?
    let playingItemId: UUID?
    let onAddSection: () -> Void
    let onSelect: (ArrangementItem) -> Void

    @Environment(ComposeEditor.self) private var editor
    @State private var availableWidth: CGFloat = 0
    @State private var draggingItemId: UUID?
    @State private var lastHoverTargetId: UUID?
    @State private var dragStartedAt: Date = .distantPast

    private let spacing: CGFloat = 4
    private let minSegment: CGFloat = 58
    private let addWidth: CGFloat = 40

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader(title: String(localized: "Arrangement"), detail: focusedItemId == nil ? String(localized: "Tap to jump · hold to reorder") : String(localized: "Focused on one section"))
                if focusedItemId != nil {
                    Button("Show all") {
                        haptic(.selection)
                        withAnimation(DesignSystem.Animations.smoothSpring) { focusedItemId = nil }
                    }
                    .font(DesignSystem.Typography.buttonSmall)
                    .foregroundStyle(DesignSystem.Colors.primaryDark)
                }
            }

            let widths = segmentWidths()
            let fits = widths.reduce(0, +) + addWidth + spacing * CGFloat(items.count) <= availableWidth + 0.5

            ScrollView(.horizontal) {
                HStack(spacing: spacing) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        if let section = item.sectionTemplate {
                            segment(item: item, section: section, width: widths[composeSafe: index] ?? minSegment)
                        }
                    }
                    addButton
                }
                .padding(.vertical, 2)
            }
            .scrollDisabled(fits)
            .scrollIndicators(.hidden)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { availableWidth = $0 }
        }
    }

    // MARK: Segment

    private func segment(item: ArrangementItem, section: SectionTemplate, width: CGFloat) -> some View {
        let isFocused = focusedItemId == item.id
        let isDimmed = focusedItemId != nil && !isFocused
        let isPlaying = playingItemId == item.id

        return Button {
            onSelect(item)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Capsule()
                    .fill(section.color)
                    .frame(height: isFocused ? 5 : 4)
                HStack(spacing: 4) {
                    if isPlaying {
                        Circle()
                            .fill(DesignSystem.Colors.brand)
                            .frame(width: 6, height: 6)
                    }
                    SectionNameLabel(name: section.name)
                }
                Text("\(section.bars)")
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 7)
            .frame(width: width, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                    .fill(isFocused ? DesignSystem.Colors.surface : section.color.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                    .stroke(isFocused ? DesignSystem.Colors.textPrimary : Color.clear, lineWidth: 1)
            )
            .opacity(isDimmed ? 0.5 : 1)
            .contentShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md))
        }
        .buttonStyle(.plain)
        .onDrag {
            draggingItemId = item.id
            dragStartedAt = Date()
            editor.beginTracking()
            haptic(.medium)
            return NSItemProvider(object: item.id.uuidString as NSString)
        }
        .onDrop(of: [UTType.text], delegate: ArrangementDropDelegate(
            targetItem: item,
            onItemHovered: hover,
            onDrop: drop,
            onExit: { lastHoverTargetId = nil }
        ))
        .accessibilityLabel("\(section.name), \(section.bars) bars")
        .accessibilityHint(focusedItemId == nil ? "Double-tap to jump to this section" : "Double-tap to focus this section")
        .accessibilityAddTraits(isFocused ? .isSelected : [])
    }

    private var addButton: some View {
        Button {
            haptic(.medium)
            onAddSection()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .frame(width: addWidth)
                .frame(maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                        .strokeBorder(DesignSystem.Colors.borderActive, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add section")
    }

    // MARK: Layout

    private func segmentWidths() -> [CGFloat] {
        let bars = items.map { CGFloat(max(1, $0.sectionTemplate?.bars ?? 1)) }
        let total = max(1, bars.reduce(0, +))
        let usable = max(0, availableWidth - addWidth - spacing * CGFloat(items.count))
        return bars.map { max(minSegment, usable * $0 / total) }
    }

    // MARK: Reorder

    private func hover(_ target: ArrangementItem) {
        // onDrag has no cancel callback: ignore stale drags (e.g. a chord dragged over the strip later).
        guard let source = draggingItemId, Date().timeIntervalSince(dragStartedAt) < 20,
              source != target.id, lastHoverTargetId != target.id else { return }
        lastHoverTargetId = target.id
        haptic(.selection)
        withAnimation(DesignSystem.Animations.quickSpring) {
            ComposeChordOps.moveItem(sourceId: source, targetId: target.id, in: project)
        }
    }

    private func drop(_ target: ArrangementItem, _ providers: [NSItemProvider]) -> Bool {
        guard draggingItemId != nil else { return false }
        // The live hover already moved the item; record the whole gesture as one undo step.
        draggingItemId = nil
        lastHoverTargetId = nil
        editor.commitTracking(String(localized: "Reorder sections"))
        haptic(.success)
        return true
    }
}

extension Array {
    subscript(composeSafe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
