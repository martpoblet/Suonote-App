import SwiftUI
import SwiftData

/// Settings: appearance, sync, intro, credits.
struct LibrarySettingsView: View {
    @State private var settings = AppSettings.shared
    @State private var showingCredits = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var demoAdded = false
    @State private var languageChanged = false

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return String(localized: "Version \(version) (\(build))")
    }

    var body: some View {
        SheetScaffold(title: String(localized: "Settings"), subtitle: String(localized: "Make the notebook yours.")) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                LibraryFormGroup(title: String(localized: "Appearance")) {
                    HStack(spacing: 8) {
                        ForEach(AppSettings.AppTheme.allCases, id: \.self) { theme in
                            SelectableChip(title: theme.title, icon: theme.icon, isSelected: settings.theme == theme) {
                                HapticFeedback.selection.trigger()
                                settings.theme = theme
                            }
                        }
                    }
                }

                LibraryFormGroup(title: String(localized: "Language")) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        HStack(spacing: 8) {
                            ForEach(AppSettings.AppLanguage.allCases, id: \.self) { language in
                                SelectableChip(title: language.title, icon: language == .system ? "globe" : nil, isSelected: settings.appLanguage == language) {
                                    HapticFeedback.selection.trigger()
                                    settings.appLanguage = language
                                    languageChanged = true
                                }
                            }
                        }
                        Text(languageChanged
                             ? "The new language applies fully the next time you open Suonote."
                             : "Changes apply fully the next time you open Suonote.")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(languageChanged ? DesignSystem.Colors.primaryDark : DesignSystem.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                LibraryFormGroup(title: "iCloud") {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sync")
                                .font(DesignSystem.Typography.headline)
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                            Text("Songs sync across your devices automatically.")
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }
                        Spacer(minLength: DesignSystem.Spacing.xs)
                        SyncStatusIndicator(style: .full)
                    }
                    .padding(DesignSystem.Spacing.md)
                    .cardStyle()
                }

                LibraryFormGroup(title: String(localized: "About")) {
                    VStack(spacing: 0) {
                        linkRow(title: String(localized: "Replay the introduction"), icon: "sparkles") {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                withAnimation(DesignSystem.Animations.gentleEase) {
                                    settings.showOnboarding = true
                                }
                            }
                        }
                        Hairline().padding(.leading, 52)
                        linkRow(title: demoAdded ? String(localized: "Demo song added to your library") : String(localized: "Add the demo song"), icon: "music.note.house") {
                            guard !demoAdded else { return }
                            DemoSong.replace(in: modelContext)
                            HapticFeedback.success.trigger()
                            demoAdded = true
                        }
                        Hairline().padding(.leading, 52)
                        linkRow(title: String(localized: "Sound credits"), icon: "music.quarternote.3") {
                            showingCredits = true
                        }
                    }
                    .cardStyle()
                }

                VStack(spacing: DesignSystem.Spacing.xs) {
                    AppLogoView(height: 18)
                    Text(versionString)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, DesignSystem.Spacing.md)
            }
        }
        .presentationDetents([.large])
        .studioModalStyle()
        .sheet(isPresented: $showingCredits) {
            SoundFontCreditsView()
        }
    }

    private func linkRow(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.primaryDark)
                    .frame(width: 24)
                Text(title)
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
