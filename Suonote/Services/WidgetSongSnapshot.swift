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

    /// Everything the widget draws except `updatedAt`. Two snapshots with the
    /// same signature look identical, so the timelines need no reload.
    var contentSignature: String {
        let parts = sections.map { "\($0.name)#\($0.colorHex)#\($0.bars)" }.joined(separator: "|")
        return [id, title, status, keyRoot, keyMode, "\(bpm)", "\(timeTop)/\(timeBottom)", "\(takes)", parts]
            .joined(separator: "\u{1F}")
    }

    @MainActor private static var lastReloadedSignature: String?
    @MainActor private static var pendingReload: Task<Void, Never>?

    /// Saves the song for the widget and, when what the widget shows has
    /// actually changed, asks WidgetKit to redraw. Reloads are debounced
    /// because this is called on nearly every edit.
    @MainActor
    static func publish(_ project: Project) {
        guard let defaults = UserDefaults(suiteName: appGroup) else { return }
        let snapshot = WidgetSongSnapshot(project: project)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: defaultsKey)

        let signature = snapshot.contentSignature
        guard signature != lastReloadedSignature else { return }
        pendingReload?.cancel()
        pendingReload = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            lastReloadedSignature = signature
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Forgets the song if the widget is currently showing this project
    /// (called when the project is deleted).
    @MainActor
    static func clear(ifShowing projectID: UUID) {
        guard let defaults = UserDefaults(suiteName: appGroup) else { return }
        let idString = projectID.uuidString
        var showsProject = defaults.string(forKey: "widget_projectId") == idString
        if let data = defaults.data(forKey: defaultsKey),
           let stored = try? JSONDecoder().decode(WidgetSongSnapshot.self, from: data),
           stored.id == idString {
            showsProject = true
        }
        guard showsProject else { return }
        pendingReload?.cancel()
        pendingReload = nil
        lastReloadedSignature = nil
        defaults.removeObject(forKey: defaultsKey)
        // Keys written by earlier versions of the app.
        for key in ["widget_projectName", "widget_projectId", "widget_keyRoot",
                    "widget_keyMode", "widget_bpm", "widget_lastEdited"] {
            defaults.removeObject(forKey: key)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
