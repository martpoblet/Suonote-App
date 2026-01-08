import Foundation

enum TimeSignaturePreset: String, CaseIterable, Identifiable {
    case threeFour = "3/4"
    case fourFour = "4/4"
    case fiveFour = "5/4"
    case sixEight = "6/8"
    case sevenEight = "7/8"
    case twelveEight = "12/8"

    var id: String { rawValue }

    var top: Int {
        switch self {
        case .threeFour: return 3
        case .fourFour: return 4
        case .fiveFour: return 5
        case .sixEight: return 6
        case .sevenEight: return 7
        case .twelveEight: return 12
        }
    }

    var bottom: Int {
        switch self {
        case .threeFour, .fourFour, .fiveFour:
            return 4
        case .sixEight, .sevenEight, .twelveEight:
            return 8
        }
    }

    var isCompound: Bool {
        bottom == 8 && (top == 6 || top == 12)
    }

    var tempoBeatsPerBar: Int {
        isCompound ? max(1, top / 3) : top
    }

    var eighthsPerTempoBeat: Int {
        if isCompound {
            return 3
        }
        return bottom == 4 ? 2 : 1
    }

    func secondsPerTempoBeat(bpm: Int) -> Double {
        60.0 / Double(max(1, bpm))
    }

    func secondsPerGridBeat(bpm: Int) -> Double {
        let secondsPerEighth = secondsPerTempoBeat(bpm: bpm) / Double(eighthsPerTempoBeat)
        let eighthsPerGridBeat = bottom == 4 ? 2.0 : 1.0
        return secondsPerEighth * eighthsPerGridBeat
    }

    func quarterNoteBpm(from bpm: Int) -> Double {
        let quarterPerTempoBeat = Double(eighthsPerTempoBeat) / 2.0
        return Double(bpm) * quarterPerTempoBeat
    }

    static func from(top: Int, bottom: Int) -> TimeSignaturePreset {
        allCases.first { $0.top == top && $0.bottom == bottom } ?? .fourFour
    }
}
