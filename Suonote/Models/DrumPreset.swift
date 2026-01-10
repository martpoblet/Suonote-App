import Foundation

enum DrumPreset: String, Codable, CaseIterable, Identifiable {
    case basic
    case drive
    case halfTime
    case sparse
    case fourOnFloor
    case offbeat

    var id: String { rawValue }

    var title: String {
        switch self {
        case .basic: return "Basic"
        case .drive: return "Drive"
        case .halfTime: return "Half Time"
        case .sparse: return "Sparse"
        case .fourOnFloor: return "4 On Floor"
        case .offbeat: return "Offbeat"
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
            return [.basic, .drive, .halfTime]
        case .rock:
            return [.drive, .halfTime, .basic]
        case .lofi:
            return [.sparse, .basic, .offbeat]
        case .edm:
            return canFourOnFloor ? [.fourOnFloor, .offbeat, .drive] : [.offbeat, .drive, .basic]
        case .jazz:
            return [.sparse, .offbeat, .basic]
        case .hiphop:
            return [.drive, .halfTime, .basic]
        case .funk:
            return [.offbeat, .drive, .basic]
        case .ambient:
            return [.sparse, .basic, .halfTime]
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
