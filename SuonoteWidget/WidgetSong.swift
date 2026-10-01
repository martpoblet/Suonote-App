import Foundation

/// The song the widget shows. Same JSON shape the app writes
/// (`Suonote/Services/WidgetSongSnapshot.swift` — keep the two in sync).
struct WidgetSong: Codable {
    struct Section: Codable {
        let name: String
        let colorHex: String
        let bars: Int
    }

    let id: String
    let title: String
    let status: String
    let keyRoot: String
    let keyMode: String
    let bpm: Int
    let timeTop: Int
    let timeBottom: Int
    let sections: [Section]
    let takes: Int
    let updatedAt: Date

    static let appGroup = "group.MartinCode.Suonote.shared"

    /// The last song you worked on, or nil before you've opened one.
    static func load() -> WidgetSong? {
        guard let defaults = UserDefaults(suiteName: appGroup) else { return nil }
        if let data = defaults.data(forKey: "widget_song"),
           let song = try? JSONDecoder().decode(WidgetSong.self, from: data) {
            return song
        }
        // Data written by earlier versions of the app.
        guard let title = defaults.string(forKey: "widget_projectName") else { return nil }
        return WidgetSong(
            id: defaults.string(forKey: "widget_projectId") ?? "",
            title: title,
            status: "In Progress",
            keyRoot: defaults.string(forKey: "widget_keyRoot") ?? "C",
            keyMode: defaults.string(forKey: "widget_keyMode") ?? "Major",
            bpm: max(1, defaults.integer(forKey: "widget_bpm")),
            timeTop: 4,
            timeBottom: 4,
            sections: [],
            takes: 0,
            updatedAt: defaults.object(forKey: "widget_lastEdited") as? Date ?? .now
        )
    }

    /// Shown in the widget gallery.
    static let sample = WidgetSong(
        id: "",
        title: "Golden Hour",
        status: "In Progress",
        keyRoot: "G",
        keyMode: "Major",
        bpm: 96,
        timeTop: 4,
        timeBottom: 4,
        sections: [
            Section(name: String(localized: "Intro"), colorHex: "7FC7CF", bars: 4),
            Section(name: String(localized: "Verse"), colorHex: "7A9ED3", bars: 8),
            Section(name: String(localized: "Pre-Chorus"), colorHex: "D8BD8B", bars: 4),
            Section(name: String(localized: "Chorus"), colorHex: "E09484", bars: 8),
            Section(name: String(localized: "Verse"), colorHex: "7A9ED3", bars: 8),
            Section(name: String(localized: "Chorus"), colorHex: "E09484", bars: 8),
            Section(name: String(localized: "Bridge"), colorHex: "C18ACB", bars: 4),
            Section(name: String(localized: "Chorus"), colorHex: "E09484", bars: 8),
            Section(name: String(localized: "Outro"), colorHex: "8FB096", bars: 4),
        ],
        takes: 3,
        updatedAt: .now.addingTimeInterval(-3_600)
    )

    // MARK: Display

    /// "G", "Am", "D dór".
    var keyShort: String {
        switch keyMode {
        case "Major": return keyRoot
        case "Minor", "Aeolian": return "\(keyRoot)m"
        default: return "\(keyRoot) \(String(Self.modeName(keyMode).prefix(3)).lowercased())"
        }
    }

    var meter: String { "\(timeTop)/\(timeBottom)" }

    var statusName: String {
        switch status {
        case "Idea": return String(localized: "Idea")
        case "In Progress": return String(localized: "In progress")
        case "Polished": return String(localized: "Polished")
        case "Finished": return String(localized: "Finished")
        case "Archived": return String(localized: "Archived")
        default: return status
        }
    }

    /// "Edited 2 hr. ago" / "Editada hace 2 h".
    func edited(relativeTo now: Date) -> String {
        guard now.timeIntervalSince(updatedAt) >= 60 else { return String(localized: "Edited just now") }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return String(localized: "Edited \(formatter.localizedString(for: updatedAt, relativeTo: now))")
    }

    func link(_ tab: String? = nil) -> URL? {
        guard !id.isEmpty else { return URL(string: "suonote://") }
        return URL(string: "suonote://project/\(id)" + (tab.map { "/\($0)" } ?? ""))
    }

    static func modeName(_ raw: String) -> String {
        switch raw {
        case "Major": return String(localized: "Major")
        case "Minor": return String(localized: "Minor")
        case "Dorian": return String(localized: "Dorian")
        case "Phrygian": return String(localized: "Phrygian")
        case "Lydian": return String(localized: "Lydian")
        case "Mixolydian": return String(localized: "Mixolydian")
        case "Aeolian": return String(localized: "Aeolian")
        case "Locrian": return String(localized: "Locrian")
        case "Harmonic Minor": return String(localized: "Harmonic Minor")
        case "Melodic Minor": return String(localized: "Melodic Minor")
        case "Pentatonic Major": return String(localized: "Pentatonic Major")
        case "Pentatonic Minor": return String(localized: "Pentatonic Minor")
        case "Blues": return String(localized: "Blues")
        default: return raw
        }
    }
}
