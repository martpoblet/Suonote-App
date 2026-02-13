import WidgetKit
import SwiftUI

// MARK: - App Colors (mirrored from DesignSystem for widget target)

private enum WidgetColors {
    static let teal = Color(red: 0/255, green: 204/255, blue: 190/255)       // #00CCBE
    static let tealDark = Color(red: 0/255, green: 175/255, blue: 163/255)   // #00AFA3
    static let tealLight = Color(red: 143/255, green: 233/255, blue: 227/255) // #8FE9E3
    static let peach = Color(red: 227/255, green: 168/255, blue: 148/255)    // #E3A894
    static let charcoal = Color(red: 47/255, green: 46/255, blue: 53/255)    // #2F2E35
    static let gray = Color(red: 110/255, green: 116/255, blue: 128/255)     // #6E7480
    static let surface = Color(red: 246/255, green: 247/255, blue: 251/255)  // #F6F7FB
    static let background = Color(red: 251/255, green: 250/255, blue: 253/255) // #FBFAFD
    static let border = Color(red: 227/255, green: 230/255, blue: 240/255)   // #E3E6F0
}

// MARK: - Suonote Logo

private struct SuonoteLogoView: View {
    let height: CGFloat

    var body: some View {
        Image("WidgetLogo")
            .resizable()
            .scaledToFit()
            .frame(height: height)
    }
}

// MARK: - Relative Time Formatter (minutes minimum)

private func relativeTimeString(from date: Date) -> String {
    let seconds = Int(Date.now.timeIntervalSince(date))
    let minutes = seconds / 60
    let hours = minutes / 60
    let days = hours / 24

    if days > 0 {
        return days == 1 ? "1 day ago" : "\(days) days ago"
    } else if hours > 0 {
        return hours == 1 ? "1 hr ago" : "\(hours) hrs ago"
    } else if minutes > 0 {
        return minutes == 1 ? "1 min ago" : "\(minutes) min ago"
    } else {
        return "Just now"
    }
}

// MARK: - Timeline Entry

struct SuonoteEntry: TimelineEntry {
    let date: Date
    let projectId: String?
    let projectName: String
    let keyRoot: String
    let keyMode: String
    let bpm: Int
    let sectionCount: Int
    let lastEdited: Date

    var deepLinkURL: URL? {
        guard let projectId else { return nil }
        return URL(string: "suonote://project/\(projectId)")
    }
}

// MARK: - Provider

struct SuonoteProvider: TimelineProvider {

    func placeholder(in context: Context) -> SuonoteEntry {
        SuonoteEntry(
            date: .now,
            projectId: nil,
            projectName: "My Song",
            keyRoot: "C",
            keyMode: "Major",
            bpm: 120,
            sectionCount: 4,
            lastEdited: .now
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SuonoteEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SuonoteEntry>) -> Void) {
        let entry = loadLatestProject() ?? placeholder(in: context)
        // Refresh every 15 minutes so relative time stays accurate
        let timeline = Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(60 * 15)))
        completion(timeline)
    }

    private func loadLatestProject() -> SuonoteEntry? {
        guard let defaults = UserDefaults(suiteName: "group.MartinCode.Suonote.shared"),
              let name = defaults.string(forKey: "widget_projectName") else {
            return nil
        }
        return SuonoteEntry(
            date: .now,
            projectId: defaults.string(forKey: "widget_projectId"),
            projectName: name,
            keyRoot: defaults.string(forKey: "widget_keyRoot") ?? "C",
            keyMode: defaults.string(forKey: "widget_keyMode") ?? "Major",
            bpm: defaults.integer(forKey: "widget_bpm"),
            sectionCount: defaults.integer(forKey: "widget_sectionCount"),
            lastEdited: defaults.object(forKey: "widget_lastEdited") as? Date ?? .now
        )
    }
}

// MARK: - Widget Views

struct SuonoteWidgetEntryView: View {
    var entry: SuonoteEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                smallView
            case .systemMedium:
                mediumView
            default:
                smallView
            }
        }
        .widgetURL(entry.deepLinkURL)
    }

    // MARK: - Small Widget

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 0) {
            SuonoteLogoView(height: 14)

            Spacer()

            Text(entry.projectName)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(WidgetColors.charcoal)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer().frame(height: 8)

            HStack(spacing: 6) {
                chipView(icon: "key.fill", text: entry.keyRoot)
                chipView(icon: "metronome", text: "\(entry.bpm)")
            }
        }
        .padding(14)
        .containerBackground(for: .widget) {
            WidgetColors.background
        }
    }

    // MARK: - Medium Widget

    private var mediumView: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                SuonoteLogoView(height: 16)

                Spacer()

                Text(entry.projectName)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(WidgetColors.charcoal)
                    .lineLimit(2)

                Spacer().frame(height: 4)

                Text(relativeTimeString(from: entry.lastEdited))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(WidgetColors.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 8) {
                statRow(icon: "key.fill", label: "Key", value: "\(entry.keyRoot) \(entry.keyMode)")
                statRow(icon: "metronome", label: "Tempo", value: "\(entry.bpm) BPM")
                statRow(icon: "list.bullet", label: "Sections", value: "\(entry.sectionCount)")
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(WidgetColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(WidgetColors.border, lineWidth: 1)
                    )
            )
            .frame(width: 140)
        }
        .padding(14)
        .containerBackground(for: .widget) {
            WidgetColors.background
        }
    }

    // MARK: - Reusable Components

    private func chipView(icon: String, text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .semibold))
            Text(text)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(WidgetColors.tealDark)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(WidgetColors.tealLight.opacity(0.35))
        )
    }

    private func statRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(WidgetColors.teal)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundStyle(WidgetColors.gray)
                Text(value)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(WidgetColors.charcoal)
                    .lineLimit(1)
            }

            Spacer()
        }
    }
}

// MARK: - Widget Configuration

struct SuonoteWidget: Widget {
    let kind: String = "SuonoteWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SuonoteProvider()) { entry in
            SuonoteWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Suonote")
        .description("Quick access to your latest songwriting project.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget Bundle

@main
struct SuonoteWidgetBundle: WidgetBundle {
    var body: some Widget {
        SuonoteWidget()
    }
}
