import Foundation

enum DrumPreset: String, Codable, CaseIterable, Identifiable {
    case basic
    case drive
    case halfTime
    case sparse
    case fourOnFloor
    case offbeat
    case shuffle
    case swing
    case trap
    case breakbeat
    case bossa
    case latin
    case boomBap

    var id: String { rawValue }

    var title: String {
        switch self {
        case .basic: return String(localized: "Basic")
        case .drive: return String(localized: "Drive")
        case .halfTime: return String(localized: "Half Time")
        case .sparse: return String(localized: "Sparse")
        case .fourOnFloor: return String(localized: "4 On Floor")
        case .offbeat: return String(localized: "Offbeat")
        case .shuffle: return String(localized: "Shuffle")
        case .swing: return String(localized: "Swing")
        case .trap: return String(localized: "Trap")
        case .breakbeat: return String(localized: "Breakbeat")
        case .bossa: return String(localized: "Bossa")
        case .latin: return String(localized: "Latin")
        case .boomBap: return String(localized: "Boom Bap")
        }
    }

    static func presets(
        for style: StudioStyle,
        beatsPerBar: Int,
        timeBottom: Int
    ) -> [DrumPreset] {
        let canFourOnFloor = timeBottom == 4 && beatsPerBar == 4

        switch style {
        case .pop:
            return [.basic, .drive, .halfTime, .shuffle, .bossa]
        case .rock:
            return [.drive, .halfTime, .basic, .breakbeat, .shuffle]
        case .lofi:
            return [.boomBap, .sparse, .basic, .offbeat, .swing, .bossa]
        case .edm:
            return canFourOnFloor ? [.fourOnFloor, .offbeat, .drive, .trap, .breakbeat] : [.offbeat, .drive, .trap, .basic]
        case .jazz:
            return [.swing, .sparse, .offbeat, .bossa, .shuffle]
        case .hiphop:
            return [.boomBap, .trap, .halfTime, .drive, .basic]
        case .funk:
            return [.offbeat, .drive, .breakbeat, .basic, .shuffle]
        case .ambient:
            return [.sparse, .basic, .halfTime, .bossa]
        }
    }

    static func defaultPreset(
        for style: StudioStyle,
        beatsPerBar: Int,
        timeBottom: Int
    ) -> DrumPreset {
        presets(for: style, beatsPerBar: beatsPerBar, timeBottom: timeBottom).first ?? .basic
    }
}
