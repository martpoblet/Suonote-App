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

    var id: String { rawValue }

    var title: String {
        switch self {
        case .basic: return "Basic"
        case .drive: return "Drive"
        case .halfTime: return "Half Time"
        case .sparse: return "Sparse"
        case .fourOnFloor: return "4 On Floor"
        case .offbeat: return "Offbeat"
        case .shuffle: return "Shuffle"
        case .swing: return "Swing"
        case .trap: return "Trap"
        case .breakbeat: return "Breakbeat"
        case .bossa: return "Bossa"
        case .latin: return "Latin"
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
            return [.sparse, .basic, .offbeat, .swing, .bossa]
        case .edm:
            return canFourOnFloor ? [.fourOnFloor, .offbeat, .drive, .trap, .breakbeat] : [.offbeat, .drive, .trap, .basic]
        case .jazz:
            return [.swing, .sparse, .offbeat, .bossa, .shuffle]
        case .hiphop:
            return [.trap, .halfTime, .drive, .basic]
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
