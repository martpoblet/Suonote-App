import SwiftUI
import UniformTypeIdentifiers

// MARK: - Track list
/// All tracks in one paper card, rows separated by hairlines. Tap a row to open
/// its editor; hold to drag-reorder or for more actions. The mixer toggle
/// reveals volume and pan for every row at once, like a console.
struct StudioTrackList: View {
    let tracks: [StudioTrack]
    let style: StudioStyle?
    let showMixer: Bool
    let canDuplicate: (StudioTrack) -> Bool
    let onTrackStructureChange: () -> Void
    let onMixChange: () -> Void
    let onDelete: (StudioTrack) -> Void
    let onDuplicate: (StudioTrack) -> Void
    let onOpenEditor: (StudioTrack) -> Void
    let onReorder: (IndexSet, Int) -> Void

    @State private var draggingId: UUID?

    private var anySolo: Bool { tracks.contains { $0.isSolo } }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                StudioTrackRow(
                    track: track,
                    style: style,
                    showMixer: showMixer,
                    isSilencedBySolo: anySolo && !track.isSolo,
                    canMoveUp: index > 0,
                    canMoveDown: index < tracks.count - 1,
                    canDuplicate: canDuplicate(track),
                    onTrackStructureChange: onTrackStructureChange,
                    onMixChange: onMixChange,
                    onDelete: { onDelete(track) },
                    onDuplicate: { onDuplicate(track) },
                    onOpenEditor: { onOpenEditor(track) },
                    onMove: { delta in
                        let destination = delta < 0 ? index - 1 : index + 2
                        withAnimation(DesignSystem.Animations.smoothSpring) {
                            onReorder(IndexSet(integer: index), max(0, min(tracks.count, destination)))
                        }
                    }
                )
                .opacity(draggingId == track.id ? 0.4 : 1)
                .onDrag {
                    draggingId = track.id
                    return NSItemProvider(object: track.id.uuidString as NSString)
                }
                .onDrop(of: [.text], delegate: StudioTrackReorderDelegate(
                    targetTrack: track,
                    tracks: tracks,
                    draggingId: $draggingId,
                    onReorder: onReorder
                ))

                if index < tracks.count - 1 {
                    Hairline()
                        .padding(.leading, 68)
                }
            }
        }
        .cardStyle()
    }
}

private struct StudioTrackReorderDelegate: DropDelegate {
    let targetTrack: StudioTrack
    let tracks: [StudioTrack]
    @Binding var draggingId: UUID?
    let onReorder: (IndexSet, Int) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggingId,
              draggingId != targetTrack.id,
              let fromIndex = tracks.firstIndex(where: { $0.id == draggingId }),
              let toIndex = tracks.firstIndex(where: { $0.id == targetTrack.id })
        else { return }
        let destination = toIndex > fromIndex ? toIndex + 1 : toIndex
        withAnimation(DesignSystem.Animations.smoothSpring) {
            onReorder(IndexSet(integer: fromIndex), destination)
        }
        haptic(.selection)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingId = nil
        return true
    }

    func validateDrop(info: DropInfo) -> Bool { true }
}

// MARK: - Track row

struct StudioTrackRow: View {
    @Bindable var track: StudioTrack
    let style: StudioStyle?
    let showMixer: Bool
    let isSilencedBySolo: Bool
    let canMoveUp: Bool
    let canMoveDown: Bool
    let canDuplicate: Bool
    let onTrackStructureChange: () -> Void
    let onMixChange: () -> Void
    let onDelete: () -> Void
    let onDuplicate: () -> Void
    let onOpenEditor: () -> Void
    let onMove: (Int) -> Void

    @EnvironmentObject private var playback: StudioPlaybackEngine
    @State private var mixDebounceTask: Task<Void, Never>?
    @State private var showingDeleteConfirm = false
    @State private var showingEffects = false

    private var isQuiet: Bool { track.isMuted || isSilencedBySolo }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    StudioInstrumentBadge(instrument: track.instrument, size: 42, isDimmed: isQuiet)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(track.name)
                            .font(DesignSystem.Typography.headline)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .lineLimit(1)
                            .accessibilityAddTraits(.isButton)
                            .accessibilityHint("Opens the track editor")
                        soundLabel
                        StudioLevelMeter(
                            level: playback.trackLevels[track.id] ?? 0,
                            isActive: playback.isPlaying && !isQuiet
                        )
                        .frame(maxWidth: 120)
                        .padding(.top, 2)
                    }
                    .opacity(isQuiet ? 0.55 : 1)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
                .onTapGesture(perform: onOpenEditor)

                StudioMixToggle(kind: .mute, isOn: track.isMuted) {
                    track.isMuted.toggle()
                    onMixChange()
                }
                StudioMixToggle(kind: .solo, isOn: track.isSolo) {
                    track.isSolo.toggle()
                    onMixChange()
                }
                moreMenu
            }

            if showMixer {
                VStack(spacing: DesignSystem.Spacing.xs) {
                    StudioSliderRow(
                        title: "Volume",
                        value: $track.volume,
                        range: 0...1,
                        valueText: "\(Int((track.volume * 100).rounded()))",
                        onChange: debouncedMixChange
                    )
                    StudioSliderRow(
                        title: "Pan",
                        value: $track.pan,
                        range: -1...1,
                        valueText: StudioMusic.panLabel(track.pan),
                        onChange: debouncedMixChange
                    )
                }
                .padding(.leading, 54)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .contentShape(Rectangle())
        .contextMenu { menuItems }
        .sheet(isPresented: $showingEffects) {
            StudioEffectsSheet(track: track)
        }
        .confirmationDialog("Delete \(track.name)?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Delete track", role: .destructive, action: onDelete)
        } message: {
            Text("Its notes and settings will be removed.")
        }
    }

    @ViewBuilder
    private var soundLabel: some View {
        if track.instrument.isAudio || track.instrument.variants.isEmpty {
            Text(track.instrument.isAudio ? String(localized: "Recording") : track.instrument.title)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .lineLimit(1)
        } else {
            Menu {
                Picker("Sound", selection: Binding(
                    get: { SoundFontManager.resolvedVariant(for: track.instrument, variant: track.variant) ?? track.instrument.variants[0] },
                    set: { newValue in
                        StudioTrackActions.applyVariant(newValue, to: track, style: style, onChange: onTrackStructureChange)
                        haptic(.selection)
                    }
                )) {
                    ForEach(track.instrument.variants, id: \.self) { variant in
                        Text(variant.displayName).tag(variant)
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Text(track.studioSoundName)
                        .font(DesignSystem.Typography.caption)
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8, weight: .bold))
                }
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Sound: \(track.studioSoundName)")
        }
    }

    private var moreMenu: some View {
        Menu {
            menuItems
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .frame(width: 30, height: 32)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("More for \(track.name)")
    }

    @ViewBuilder
    private var menuItems: some View {
        Button(action: onOpenEditor) {
            Label(track.instrument.isAudio ? "Open" : "Edit notes", systemImage: "square.and.pencil")
        }
        Button {
            showingEffects = true
        } label: {
            Label("Effects…", systemImage: "slider.horizontal.below.square.filled.and.square")
        }
        if canDuplicate {
            Button(action: onDuplicate) {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }
        }
        Divider()
        if canMoveUp {
            Button { onMove(-1) } label: { Label("Move up", systemImage: "arrow.up") }
        }
        if canMoveDown {
            Button { onMove(1) } label: { Label("Move down", systemImage: "arrow.down") }
        }
        Divider()
        Button(role: .destructive) {
            showingDeleteConfirm = true
        } label: {
            Label("Delete track", systemImage: "trash")
        }
    }

    private func debouncedMixChange() {
        mixDebounceTask?.cancel()
        mixDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 60_000_000)
            guard !Task.isCancelled else { return }
            onMixChange()
        }
    }
}
