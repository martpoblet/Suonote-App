import WidgetKit
import SwiftUI

// MARK: - Timeline

struct SuonoteEntry: TimelineEntry {
    let date: Date
    /// nil before the first song has been opened.
    let song: WidgetSong?
}

struct SuonoteProvider: TimelineProvider {

    func placeholder(in context: Context) -> SuonoteEntry {
        SuonoteEntry(date: .now, song: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (SuonoteEntry) -> Void) {
        completion(SuonoteEntry(date: .now, song: context.isPreview ? .sample : (WidgetSong.load() ?? .sample)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SuonoteEntry>) -> Void) {
        // The app reloads the widget whenever the song changes; refresh now
        // and then so "Edited … ago" stays honest.
        let entry = SuonoteEntry(date: .now, song: WidgetSong.load())
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(30 * 60))))
    }
}

// MARK: - Views

struct SuonoteWidgetEntryView: View {
    let entry: SuonoteEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let song = entry.song {
                switch family {
                case .systemMedium: MediumSongView(song: song, now: entry.date)
                case .accessoryRectangular: LockScreenSongView(song: song, now: entry.date)
                default: SmallSongView(song: song)
                }
            } else {
                EmptySongView(isMedium: family == .systemMedium, isAccessory: family == .accessoryRectangular)
            }
        }
        .containerBackground(for: .widget) {
            if family == .accessoryRectangular { Color.clear } else { WidgetInk.paper }
        }
    }
}

/// Eyebrow row: the logo waves + "CONTINUE".
private struct ContinueEyebrow: View {
    var body: some View {
        HStack(spacing: 5) {
            WidgetWavesMark(height: 8, color: WidgetInk.teal)
                .widgetAccentable()
            Text("Continue")
                .widgetEyebrow(WidgetInk.teal)
        }
    }
}

/// Colored dot + status name, like the app's status label.
private struct StatusLabel: View {
    let song: WidgetSong

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(WidgetInk.status(song.status))
                .frame(width: 5, height: 5)
            Text(song.statusName)
                .font(WidgetType.manrope(10, "Medium"))
                .foregroundStyle(WidgetInk.inkSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 2.5)
        .background(Capsule().fill(WidgetInk.surface))
    }
}

/// The song's shape: one capsule per section, sized by bars.
private struct ArrangementRibbon: View {
    let sections: [WidgetSong.Section]
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { proxy in
            let total = CGFloat(max(1, sections.reduce(0) { $0 + $1.bars }))
            let gap: CGFloat = sections.count > 1 ? 1.5 : 0
            let usable = max(0, proxy.size.width - gap * CGFloat(max(0, sections.count - 1)))
            if sections.isEmpty {
                Capsule()
                    .stroke(WidgetInk.rule, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            } else {
                HStack(spacing: gap) {
                    ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                        Capsule()
                            .fill(WidgetInk.section(section.colorHex))
                            .frame(width: max(2, usable * CGFloat(section.bars) / total))
                    }
                }
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

// MARK: Small

private struct SmallSongView: View {
    let song: WidgetSong

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ContinueEyebrow()
            Spacer(minLength: 6)
            Text(song.title)
                .font(WidgetType.erode(21, "Semibold", relativeTo: .title3))
                .foregroundStyle(WidgetInk.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .widgetAccentable()
            StatusLabel(song: song)
                .padding(.top, 5)
            Spacer(minLength: 8)
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                fact(song.keyShort)
                dot
                fact("\(song.bpm)")
                Text(" BPM")
                    .font(WidgetType.manrope(9, "SemiBold"))
                    .foregroundStyle(WidgetInk.inkTertiary)
                dot
                fact(song.meter)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            ArrangementRibbon(sections: song.sections, height: 4)
                .padding(.top, 7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(song.link())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(song.title), \(song.statusName), \(WidgetSong.modeName(song.keyMode)) \(song.keyRoot), \(song.bpm) BPM")
    }

    private func fact(_ text: String) -> some View {
        Text(text)
            .font(WidgetType.erode(15, "Medium", relativeTo: .subheadline))
            .foregroundStyle(WidgetInk.ink)
            .monospacedDigit()
    }

    private var dot: some View {
        Text("  ·  ")
            .font(WidgetType.manrope(10, "Bold"))
            .foregroundStyle(WidgetInk.inkTertiary)
    }
}

// MARK: Medium

private struct MediumSongView: View {
    let song: WidgetSong
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                ContinueEyebrow()
                Spacer(minLength: 8)
                Text(song.edited(relativeTo: now))
                    .font(WidgetType.manrope(9.5, "Medium"))
                    .foregroundStyle(WidgetInk.inkTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(song.title)
                        .font(WidgetType.erode(23, "Semibold", relativeTo: .title2))
                        .foregroundStyle(WidgetInk.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .widgetAccentable()
                    StatusLabel(song: song)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 0) {
                    factRow(String(localized: "Key"), song.keyShort)
                    rule
                    factRow(String(localized: "Tempo"), "\(song.bpm)")
                    rule
                    factRow(String(localized: "Meter"), song.meter)
                }
                .frame(width: 100)
            }

            Spacer(minLength: 8)

            ArrangementRibbon(sections: song.sections, height: 5)

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                if let url = song.link() {
                    Link(destination: url) {
                        actionPill(String(localized: "Open"), icon: "arrow.right", style: .ink)
                    }
                }
                Spacer(minLength: 0)
                if let url = song.link("studio") {
                    Link(destination: url) {
                        actionPill(String(localized: "Studio"), icon: "square.grid.2x2", style: .outline)
                    }
                }
                if let url = song.link("record") {
                    Link(destination: url) {
                        actionPill(String(localized: "Record"), icon: "mic.fill", style: .record)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func factRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .widgetEyebrow()
            Spacer(minLength: 4)
            Text(value)
                .font(WidgetType.erode(16, "Medium", relativeTo: .subheadline))
                .foregroundStyle(WidgetInk.ink)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(height: 19)
    }

    private var rule: some View {
        Rectangle()
            .fill(WidgetInk.rule)
            .frame(height: 1)
            .padding(.vertical, 2)
    }

    private enum PillStyle { case ink, outline, record }

    private func actionPill(_ title: String, icon: String, style: PillStyle) -> some View {
        HStack(spacing: 4) {
            if style == .ink {
                Text(title)
                Image(systemName: icon).font(.system(size: 8, weight: .bold))
            } else {
                Image(systemName: icon).font(.system(size: 9, weight: .semibold))
                Text(title)
            }
        }
        .font(WidgetType.manrope(11, "SemiBold"))
        .lineLimit(1)
        .foregroundStyle(style == .ink ? WidgetInk.paper : (style == .record ? WidgetInk.record : WidgetInk.ink))
        .padding(.horizontal, 10)
        .frame(height: 24)
        .background {
            if style == .ink {
                Capsule().fill(WidgetInk.ink)
            } else {
                Capsule().stroke(style == .record ? WidgetInk.record.opacity(0.45) : WidgetInk.rule, lineWidth: 1)
            }
        }
    }
}

// MARK: Lock screen

private struct LockScreenSongView: View {
    let song: WidgetSong
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                WidgetWavesMark(height: 7, color: .primary)
                    .widgetAccentable()
                Text(song.title)
                    .font(WidgetType.erode(15, "Semibold", relativeTo: .headline))
                    .lineLimit(1)
            }
            Text("\(song.keyShort) · \(song.bpm) BPM · \(song.meter)")
                .font(WidgetType.manrope(12, "SemiBold"))
                .lineLimit(1)
            Text(song.edited(relativeTo: now))
                .font(WidgetType.manrope(11, "Medium"))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(song.link())
    }
}

// MARK: Empty

private struct EmptySongView: View {
    let isMedium: Bool
    let isAccessory: Bool

    var body: some View {
        if isAccessory {
            HStack(spacing: 6) {
                WidgetWavesMark(height: 9, color: .primary).widgetAccentable()
                Text("Start a song")
                    .font(WidgetType.erode(15, "Semibold", relativeTo: .headline))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .widgetURL(URL(string: "suonote://"))
        } else {
            VStack(alignment: .leading, spacing: 0) {
                WidgetWavesMark(height: isMedium ? 16 : 14, color: WidgetInk.brand)
                    .widgetAccentable()
                Spacer(minLength: 8)
                Text("Your next song starts here.")
                    .font(WidgetType.erode(isMedium ? 22 : 19, "Semibold", relativeTo: .title3))
                    .foregroundStyle(WidgetInk.ink)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 6)
                Text("Open Suonote")
                    .font(WidgetType.manrope(10.5, "SemiBold"))
                    .foregroundStyle(WidgetInk.teal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .widgetURL(URL(string: "suonote://"))
        }
    }
}

// MARK: - Widget

struct SuonoteWidget: Widget {
    let kind: String = "SuonoteWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SuonoteProvider()) { entry in
            SuonoteWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Keep writing")
        .description("Quick access to your latest songwriting project.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

@main
struct SuonoteWidgetBundle: WidgetBundle {
    var body: some Widget {
        SuonoteWidget()
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    SuonoteWidget()
} timeline: {
    SuonoteEntry(date: .now, song: .sample)
    SuonoteEntry(date: .now, song: nil)
}

#Preview("Medium", as: .systemMedium) {
    SuonoteWidget()
} timeline: {
    SuonoteEntry(date: .now, song: .sample)
}

#Preview("Lock screen", as: .accessoryRectangular) {
    SuonoteWidget()
} timeline: {
    SuonoteEntry(date: .now, song: .sample)
}
