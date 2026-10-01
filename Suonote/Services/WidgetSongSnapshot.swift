import Foundation
import WidgetKit

/// What the home-screen widget shows about the song you're working on.
/// Written to the shared App Group as JSON; the widget target decodes the
/// same shape (`SuonoteWidget/WidgetSong.swift` — keep the two in sync).
struct WidgetSongSnapshot: Codable {
    struct Section: Codable {
        let name: String
        let colorHex: String
        let bars: Int
    }

    let id: String
    let title: String
    /// `ProjectStatus` raw value; the widget localizes it.
    let status: String
    let keyRoot: String
    /// `KeyMode` raw value; the widget localizes it.
    let keyMode: String
    let bpm: Int
    let timeTop: Int
    let timeBottom: Int
    /// The arrangement in order (repeats included).
    let sections: [Section]
    let takes: Int
    let updatedAt: Date

    static let appGroup = "group.MartinCode.Suonote.shared"
    static let defaultsKey = "widget_song"

    @MainActor
    init(project: Project) {
        id = project.id.uuidString
        title = project.title
        status = project.status.rawValue
        keyRoot = project.keyRoot
        keyMode = project.keyMode.rawValue
        bpm = project.bpm
        timeTop = project.timeTop
        timeBottom = project.timeBottom
        let arrangement = project.arrangementItems
            .sorted { $0.orderIndex < $1.orderIndex }
            .compactMap(\.sectionTemplate)
        sections = arrangement.map {
            Section(name: $0.name, colorHex: $0.colorHex ?? SectionColor.sage.hex, bars: max(1, $0.bars))
        }
        takes = project.recordingsCount
        updatedAt = project.updatedAt
    }

    /// Saves the song for the widget and asks WidgetKit to redraw.
    @MainActor
    static func publish(_ project: Project) {
        guard let defaults = UserDefaults(suiteName: appGroup),
              let data = try? JSONEncoder().encode(WidgetSongSnapshot(project: project)) else { return }
        defaults.set(data, forKey: defaultsKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
