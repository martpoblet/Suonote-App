import SwiftUI

// MARK: - Greeting header

/// Date eyebrow → Erode greeting → italic count line.
struct LibraryGreetingHeader: View {
    let songCount: Int
    let inProgressCount: Int

    var body: some View {
        TimelineView(.everyMinute) { context in
            VStack(alignment: .leading, spacing: 6) {
                Text(context.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .eyebrow()
                Text(Self.greeting(for: context.date))
                    .font(DesignSystem.Typography.largeTitle)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Text(subtitle)
                        .font(DesignSystem.Typography.italicSmall)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                    SyncStatusIndicator(style: .minimal)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // List cells clip at their edge: give glyphs whose ink overhangs
            // the origin (tracked caps, Erode italics) room to breathe.
            .padding(.leading, 3)
            .padding(.bottom, DesignSystem.Spacing.xs)
        }
    }

    private var subtitle: String {
        switch songCount {
        case 0: return String(localized: "A blank notebook, waiting.")
        case 1: return String(localized: "One song in the notebook.")
        default:
            if inProgressCount > 0 {
                return String(localized: "\(songCount) songs · \(inProgressCount) taking shape")
            }
            return String(localized: "\(songCount) songs in the notebook.")
        }
    }

    static func greeting(for date: Date) -> String {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<12: return String(localized: "Good morning")
        case 12..<18: return String(localized: "Good afternoon")
        case 18..<23: return String(localized: "Good evening")
        default: return String(localized: "Late session")
        }
    }
}

// MARK: - Continue card

/// Hero card for the most recently edited song, with one-tap entry
/// into Compose, Studio or Record.
struct LibraryContinueCard: View {
    let project: Project
    let open: (ProjectDetailTab) -> Void

    private var sectionNames: String {
        var seen = Set<String>()
        return project.libraryArrangement
            .map(\.name)
            .filter { seen.insert($0).inserted }
            .joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 6) {
                    BrandWavesMark(size: 10, color: DesignSystem.Colors.primaryDark)
                    Text("Continue")
                        .eyebrow(color: DesignSystem.Colors.primaryDark)
                }
                Spacer(minLength: 0)
                Text("Edited \(project.updatedAt.timeAgo())")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }

            Button { open(.compose) } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(project.title)
                        .font(DesignSystem.Typography.title)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    LibraryStatusLabel(status: project.status)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the song")

            LibraryFactsRow(project: project)

            if !project.libraryArrangement.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    LibraryArrangementStrip(project: project, height: 6)
                    Text("\(sectionNames)  —  \(project.libraryTotalBars) bars")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Arrangement: \(sectionNames), \(project.libraryTotalBars) bars")
            }

            Hairline()

            HStack(spacing: DesignSystem.Spacing.xs) {
                Button { open(.compose) } label: {
                    Label("Open", systemImage: "arrow.right")
                        .labelStyle(TrailingIconLabelStyle())
                }
                .buttonStyle(InkButtonStyle(compact: true))

                Spacer(minLength: 0)

                Button { open(.studio) } label: {
                    Label("Studio", systemImage: "square.grid.2x2")
                }
                .buttonStyle(OutlineButtonStyle(compact: true))

                Button { open(.record) } label: {
                    Label("Record", systemImage: "mic.fill")
                }
                .buttonStyle(OutlineButtonStyle(tint: DesignSystem.Colors.record, compact: true))
            }
            .labelStyle(.titleAndIcon)
        }
        .padding(18)
        .cardStyle()
    }
}

/// "Open →" style label.
private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.title
            configuration.icon
                .font(.system(size: 11, weight: .bold))
        }
    }
}

// MARK: - Song row

struct LibraryProjectRow: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.xs) {
                Text(project.title)
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(project.status == .archived ? DesignSystem.Colors.textSecondary : DesignSystem.Colors.textPrimary)
                    .lineLimit(2)
                Spacer(minLength: DesignSystem.Spacing.xs)
                Text(project.updatedAt.libraryShortAgo)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .monospacedDigit()
            }

            metadata

            if !project.arrangementItems.isEmpty {
                LibraryArrangementStrip(project: project, height: 3)
                    .padding(.vertical, 2)
            }

            HStack(spacing: DesignSystem.Spacing.xs) {
                LibraryStatusLabel(status: project.status)
                ForEach(project.tags.prefix(2), id: \.self) { tag in
                    Text("#\(tag)")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .lineLimit(1)
                }
                if project.tags.count > 2 {
                    Text("+\(project.tags.count - 2)")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var metadata: some View {
        HStack(spacing: 6) {
            Text(project.libraryKeyShort)
            separator
            Text("\(project.bpm) BPM")
            separator
            Text(project.libraryMeterLabel)
            if project.recordingsCount > 0 {
                separator
                HStack(spacing: 3) {
                    Image(systemName: "waveform")
                        .font(.system(size: 10, weight: .semibold))
                    Text("\(project.recordingsCount)")
                }
            }
        }
        .font(DesignSystem.Typography.caption)
        .foregroundStyle(DesignSystem.Colors.textSecondary)
        .monospacedDigit()
    }

    private var separator: some View {
        Circle()
            .fill(DesignSystem.Colors.textMuted)
            .frame(width: 2.5, height: 2.5)
    }

    private var accessibilityText: String {
        var parts = [project.title, project.status.libraryDisplayName, project.libraryKeyLabel, "\(project.bpm) BPM",
                     String(localized: "\(project.timeTop) \(project.timeBottom) time")]
        if !project.arrangementItems.isEmpty { parts.append(String(localized: "\(project.arrangementItems.count) sections")) }
        if project.recordingsCount > 0 { parts.append(String(localized: "\(project.recordingsCount) takes")) }
        parts.append(String(localized: "edited \(project.updatedAt.timeAgo())"))
        return parts.joined(separator: ", ")
    }
}

// MARK: - Empty library

struct LibraryEmptyState: View {
    let create: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            BrandWavesMark(size: 64, animated: !reduceMotion)
                .padding(.top, DesignSystem.Spacing.xxl)

            VStack(spacing: DesignSystem.Spacing.xs) {
                Text("Every song starts as a sketch.")
                    .font(DesignSystem.Typography.title2)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Name an idea, set a tempo, and hear it back in seconds.")
                    .font(DesignSystem.Typography.italicSmall)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 300)

            Button(action: create) {
                Label("Start a song", systemImage: "plus")
            }
            .buttonStyle(InkButtonStyle())

            VStack(alignment: .leading, spacing: 0) {
                step("1", "Compose", "Sections, chords and a shape.")
                Hairline().padding(.leading, 44)
                step("2", "Studio", "Drums, bass and keys play it back.")
                Hairline().padding(.leading, 44)
                step("3", "Record", "Sing over it. Keep the best take.")
            }
            .cardStyle()
            .padding(.top, DesignSystem.Spacing.md)
        }
        .frame(maxWidth: .infinity)
    }

    private func step(_ number: String, _ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Text(number)
                .font(DesignSystem.Typography.title3)
                .foregroundStyle(DesignSystem.Colors.primaryDark)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Text(detail)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .accessibilityElement(children: .combine)
    }
}
