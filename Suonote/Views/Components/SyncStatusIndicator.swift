import SwiftUI
import SwiftData

struct SyncStatusIndicator: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showDetails = false
    @State private var isAnimating = false
    @State private var rotation: Double = 0
    @AppStorage("sync_lastSuccess") private var lastSyncTime: Double = 0
    @AppStorage("sync_pendingSince") private var pendingSince: Double = 0

    private var statusIcon: String {
        modelContext.hasChanges ? "icloud.and.arrow.up" : "icloud"
    }

    private var statusColor: Color {
        modelContext.hasChanges ? DesignSystem.Colors.warning : DesignSystem.Colors.success
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { _ in
            Button {
                showDetails = true
            } label: {
                HStack(spacing: 6) {
                    ZStack {
                        Image(systemName: "icloud")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(statusColor)
                            .opacity(modelContext.hasChanges ? 0 : 1)
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(statusColor)
                            .rotationEffect(.degrees(rotation))
                            .opacity(modelContext.hasChanges ? 1 : 0)
                    }
                    .frame(width: 16, height: 16)

                    if modelContext.hasChanges {
                        Text("Sync…")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                            .fixedSize()
                            .layoutPriority(1)
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                    }
                }
                .contentShape(Rectangle())
                .accessibilityLabel(modelContext.hasChanges ? "Syncing" : "Synced")
                .animation(.easeInOut(duration: 0.2), value: modelContext.hasChanges)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showDetails) {
                SyncDetailsSheet(hasChanges: modelContext.hasChanges)
                    .presentationDetents([.fraction(0.42)])
                    .presentationDragIndicator(.visible)
            }
            .onAppear {
                updateAnimationState(isSyncing: modelContext.hasChanges)
                if !modelContext.hasChanges, lastSyncTime == 0 {
                    lastSyncTime = Date().timeIntervalSince1970
                }
            }
            .onChange(of: modelContext.hasChanges) { _, newValue in
                updateAnimationState(isSyncing: newValue)
            }
        }
    }

    private func updateAnimationState(isSyncing: Bool) {
        isAnimating = isSyncing
        if isSyncing {
            if pendingSince == 0 {
                pendingSince = Date().timeIntervalSince1970
            }
            rotation = 0
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) { rotation = 360 }
        } else {
            pendingSince = 0
            lastSyncTime = Date().timeIntervalSince1970
            withAnimation(.none) { rotation = 0 }
        }
    }
}

private struct SyncDetailsSheet: View {
    let hasChanges: Bool
    @Environment(\.dismiss) private var dismiss
    @AppStorage("sync_lastSuccess") private var lastSyncTime: Double = 0
    @AppStorage("sync_pendingSince") private var pendingSince: Double = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(DesignSystem.Colors.surfaceSecondary)
                            .frame(width: 46, height: 46)
                        Image(systemName: hasChanges ? "arrow.triangle.2.circlepath" : "icloud")
                            .font(DesignSystem.Typography.title3)
                            .foregroundStyle(hasChanges ? DesignSystem.Colors.warning : DesignSystem.Colors.success)
                            .rotationEffect(.degrees(hasChanges ? 360 : 0))
                            .animation(hasChanges ? .linear(duration: 1.1).repeatForever(autoreverses: false) : .default, value: hasChanges)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("iCloud Sync")
                            .font(DesignSystem.Typography.title3)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                        Text(statusSubtitle)
                            .font(DesignSystem.Typography.callout)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(hasChanges
                         ? "Changes are pending. Sync runs automatically in the background when the device is online."
                         : "All changes are saved locally. iCloud keeps syncing automatically in the background.")
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)

                    Text("Details")
                        .font(DesignSystem.Typography.calloutBold)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)

                    Text(detailsText)
                        .font(DesignSystem.Typography.callout)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(DesignSystem.Colors.surfaceSecondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(DesignSystem.Colors.border.opacity(0.6), lineWidth: 1)
                        )
                )

                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(DesignSystem.Typography.bodyBold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(DesignSystem.Colors.primary)
                        .foregroundStyle(DesignSystem.Colors.textWhite)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(20)
        }
        .background(DesignSystem.Colors.background)
    }

    private var statusSubtitle: String {
        if hasChanges {
            if pendingSince > 0 && Date().timeIntervalSince1970 - pendingSince > 120 {
                return "Sync paused — check iCloud storage"
            }
            return "Syncing changes…"
        }
        return "Up to date"
    }

    private var detailsText: String {
        let lastSync = lastSyncTime > 0 ? relativeDateString(from: Date(timeIntervalSince1970: lastSyncTime)) : "Never"
        var lines = [
            "• Last sync: \(lastSync)",
            "• Sync may take a few moments depending on connection.",
            "• Your data is safe locally while it syncs."
        ]
        if pendingSince > 0 {
            let pending = relativeDateString(from: Date(timeIntervalSince1970: pendingSince))
            lines.insert("• Pending changes since: \(pending)", at: 1)
        }
        if hasChanges && pendingSince > 0 && Date().timeIntervalSince1970 - pendingSince > 120 {
            lines.append("• If sync doesn’t resume, free up iCloud storage.")
        }
        return lines.joined(separator: "\n")
    }

    private func relativeDateString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct CloudStatusSummary: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("sync_lastSuccess") private var lastSyncTime: Double = 0
    @AppStorage("sync_pendingSince") private var pendingSince: Double = 0

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(DesignSystem.Typography.caption2)
                .foregroundStyle(statusColor)
            Text(statusText)
                .font(DesignSystem.Typography.caption2)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
    }

    private var iconName: String {
        modelContext.hasChanges ? "arrow.triangle.2.circlepath" : "icloud"
    }

    private var statusText: String {
        if modelContext.hasChanges {
            if pendingSince > 0 && Date().timeIntervalSince1970 - pendingSince > 120 {
                return "Cloud paused (quota)"
            }
            return "Syncing to iCloud…"
        }
        if lastSyncTime > 0 {
            return "Synced \(relativeDateString(from: Date(timeIntervalSince1970: lastSyncTime)))"
        }
        return "Sync pending"
    }

    private var statusColor: Color {
        if modelContext.hasChanges {
            if pendingSince > 0 && Date().timeIntervalSince1970 - pendingSince > 120 {
                return DesignSystem.Colors.warning
            }
            return DesignSystem.Colors.warning
        }
        return DesignSystem.Colors.success
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
