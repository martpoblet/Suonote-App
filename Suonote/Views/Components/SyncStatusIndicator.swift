import SwiftUI
import SwiftData

struct SyncStatusIndicator: View {
    enum Style {
        case full
        case minimal
    }

    @Environment(\.modelContext) private var modelContext
    @State private var showDetails = false
    @State private var isAnimating = false
    @State private var rotation: Double = 0
    @State private var spinTask: Task<Void, Never>?
    @AppStorage(SyncStatusDefaultsKeys.lastSuccess) private var lastSyncTime: Double = 0
    @AppStorage(SyncStatusDefaultsKeys.pendingSince) private var pendingSince: Double = 0
    @AppStorage(SyncStatusDefaultsKeys.lastFailure) private var lastFailureTime: Double = 0
    @AppStorage(SyncStatusDefaultsKeys.lastFailureCode) private var lastFailureCodeRaw: Int = SyncFailureCode.none.rawValue
    @AppStorage(SyncStatusDefaultsKeys.lastErrorMessage) private var lastErrorMessage: String = ""
    let style: Style

    init(style: Style = .full) {
        self.style = style
    }

    private var statusColor: Color {
        switch syncState {
        case .synced:
            return DesignSystem.Colors.textTertiary
        case .syncing:
            return DesignSystem.Colors.primaryDark
        case .paused:
            return DesignSystem.Colors.warning
        case .failed:
            return DesignSystem.Colors.error
        }
    }

    private enum SyncState {
        case synced
        case syncing
        case paused
        case failed
    }

    private var failureCode: SyncFailureCode {
        SyncFailureCode(rawValue: lastFailureCodeRaw) ?? .unknown
    }

    private var hasActiveFailure: Bool {
        lastFailureTime > 0 && failureCode != .none
    }

    private var statusText: String {
        switch syncState {
        case .synced:
            return String(localized: "Synced")
        case .syncing:
            return String(localized: "Syncing…")
        case .paused:
            return String(localized: "Sync paused")
        case .failed:
            return String(localized: "Sync failed")
        }
    }

    private var syncState: SyncState {
        if hasActiveFailure {
            return .failed
        }

        if modelContext.hasChanges {
            if pendingSince > 0 && Date().timeIntervalSince1970 - pendingSince > 120 {
                return .paused
            }
            return .syncing
        }
        return .synced
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { _ in
            Button {
                showDetails = true
            } label: {
                HStack(spacing: 6) {
                    ZStack {
                        Image(systemName: "checkmark.icloud")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(statusColor)
                            .opacity(syncState == .synced ? 1 : 0)
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(statusColor)
                            .rotationEffect(.degrees(rotation))
                            .opacity(syncState == .syncing ? 1 : 0)
                        Image(systemName: "exclamationmark.icloud")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.warning)
                            .opacity(syncState == .paused ? 1 : 0)
                        Image(systemName: "xmark.icloud")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.error)
                            .opacity(syncState == .failed ? 1 : 0)
                    }
                    .frame(width: 16, height: 16)

                    if style == .full || syncState != .synced {
                        Text(statusText)
                            .font(DesignSystem.Typography.caption2)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                            .fixedSize()
                            .layoutPriority(1)
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                    }
                }
                .contentShape(Rectangle())
                .accessibilityLabel("iCloud: \(statusText)")
                .accessibilityHint("Shows sync details")
                .animation(.easeInOut(duration: 0.2), value: syncState)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showDetails) {
                SyncDetailsSheet(
                    hasChanges: modelContext.hasChanges,
                    hasFailure: hasActiveFailure,
                    failureCode: failureCode,
                    lastErrorMessage: lastErrorMessage,
                    isPaused: syncState == .paused
                )
                    .presentationDetents([.medium, .large])
                    .studioModalStyle()
            }
            .onAppear {
                updateAnimationState(state: syncState)
            }
            .onChange(of: syncState) { _, newValue in
                updateAnimationState(state: newValue)
            }
        }
    }

    private func updateAnimationState(state: SyncState) {
        spinTask?.cancel()
        spinTask = nil

        isAnimating = (state == .syncing)
        if state == .syncing {
            if pendingSince == 0 {
                pendingSince = Date().timeIntervalSince1970
            }
            rotation = 0
            spinTask = Task { @MainActor in
                while !Task.isCancelled {
                    withAnimation(.linear(duration: 1.0)) {
                        rotation += 360
                    }
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
            }
        } else if state == .synced {
            pendingSince = 0
            withAnimation(.none) { rotation = 0 }
        } else {
            withAnimation(.none) { rotation = 0 }
        }
    }
}

private struct SyncDetailsSheet: View {
    let hasChanges: Bool
    let hasFailure: Bool
    let failureCode: SyncFailureCode
    let lastErrorMessage: String
    let isPaused: Bool
    @AppStorage(SyncStatusDefaultsKeys.lastSuccess) private var lastSyncTime: Double = 0
    @AppStorage(SyncStatusDefaultsKeys.pendingSince) private var pendingSince: Double = 0
    @AppStorage(SyncStatusDefaultsKeys.lastFailure) private var lastFailureTime: Double = 0

    private var isSyncing: Bool { hasChanges && !hasFailure && !isPaused }

    var body: some View {
        SheetScaffold(title: String(localized: "iCloud sync"), subtitle: statusSubtitle) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ZStack {
                        Circle()
                            .fill(statusIconColor.opacity(0.14))
                            .frame(width: 44, height: 44)
                        Image(systemName: statusIconName)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(statusIconColor)
                            .symbolEffect(.rotate, options: .repeating, isActive: isSyncing)
                    }
                    Text(summaryText)
                        .font(DesignSystem.Typography.callout)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 0) {
                    ForEach(Array(facts.enumerated()), id: \.offset) { index, fact in
                        if index > 0 { Hairline().padding(.leading, DesignSystem.Spacing.md) }
                        HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.sm) {
                            Text(fact.label)
                                .font(DesignSystem.Typography.callout)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                            Spacer(minLength: DesignSystem.Spacing.sm)
                            Text(fact.value)
                                .font(DesignSystem.Typography.calloutBold)
                                .foregroundStyle(fact.isProblem ? DesignSystem.Colors.error : DesignSystem.Colors.textPrimary)
                                .multilineTextAlignment(.trailing)
                        }
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                    }
                }
                .cardStyle()

                Text(footnote)
                    .font(DesignSystem.Typography.italicSmall)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var facts: [(label: String, value: String, isProblem: Bool)] {
        var rows: [(String, String, Bool)] = [
            (String(localized: "Last sync"), lastSyncTime > 0 ? relativeDateString(from: Date(timeIntervalSince1970: lastSyncTime)) : String(localized: "Never"), false)
        ]
        if pendingSince > 0 {
            rows.append((String(localized: "Pending since"), relativeDateString(from: Date(timeIntervalSince1970: pendingSince)), false))
        }
        if hasFailure {
            if lastFailureTime > 0 {
                rows.append((String(localized: "Last failed export"), relativeDateString(from: Date(timeIntervalSince1970: lastFailureTime)), true))
            }
            let message = lastErrorMessage.trimmingCharacters(in: .whitespacesAndNewlines)
            rows.append((String(localized: "Error"), message.isEmpty ? failureCode.userMessage : message, true))
        }
        return rows
    }

    private var footnote: String {
        if hasFailure && failureCode == .quotaExceeded {
            return String(localized: "Free up iCloud storage to resume sync. Your songs are safe on this device.")
        }
        if hasChanges && isPaused {
            return String(localized: "If sync doesn't resume, check your connection and iCloud storage.")
        }
        return String(localized: "Sync can take a few moments depending on your connection.")
    }

    private var statusIconName: String {
        if hasFailure {
            return "xmark.icloud"
        }
        if isPaused {
            return "exclamationmark.icloud"
        }
        if hasChanges {
            return "arrow.triangle.2.circlepath"
        }
        return "icloud"
    }

    private var statusIconColor: Color {
        if hasFailure {
            return DesignSystem.Colors.error
        }
        if hasChanges || isPaused {
            return DesignSystem.Colors.warning
        }
        return DesignSystem.Colors.success
    }

    private var summaryText: String {
        if hasFailure {
            return String(localized: "The latest upload to iCloud failed. Your changes stay safe on this device until sync resumes.")
        }
        return hasChanges
            ? String(localized: "Changes are waiting to upload. Sync runs in the background whenever you're online.")
            : String(localized: "Everything is saved on this device and in iCloud. Sync keeps running in the background.")
    }

    private var statusSubtitle: String {
        if hasFailure {
            if failureCode == .quotaExceeded {
                return String(localized: "Paused — iCloud storage is full.")
            }
            return String(localized: "Something went wrong.")
        }

        if hasChanges {
            if isPaused {
                return String(localized: "Paused for now.")
            }
            return String(localized: "Syncing your changes…")
        }
        return String(localized: "Up to date.")
    }

    private func relativeDateString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}


#Preview {
    SyncStatusIndicator()
        .padding()
}
