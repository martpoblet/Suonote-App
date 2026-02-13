import Foundation
import Observation

/// Calculates BPM from a series of taps (U-05)
@Observable
class TapTempo {
    var currentBPM: Int = 0
    var tapCount: Int = 0
    
    private var taps: [Date] = []
    private let maxTaps = 8
    private let resetInterval: TimeInterval = 2.0
    
    func tap() {
        let now = Date()
        
        // Reset if too long since last tap
        if let last = taps.last, now.timeIntervalSince(last) > resetInterval {
            taps.removeAll()
        }
        
        taps.append(now)
        if taps.count > maxTaps {
            taps.removeFirst()
        }
        
        tapCount = taps.count
        
        guard taps.count >= 2 else {
            currentBPM = 0
            return
        }
        
        let totalInterval = taps.last!.timeIntervalSince(taps.first!)
        let averageInterval = totalInterval / Double(taps.count - 1)
        let bpm = 60.0 / averageInterval
        currentBPM = max(20, min(300, Int(bpm.rounded())))
    }
    
    func reset() {
        taps.removeAll()
        tapCount = 0
        currentBPM = 0
    }
}
