import SwiftUI

/// Audio level meter with clipping indicator (P-09)
struct AudioLevelMeter: View {
    let level: Float  // 0.0 to 1.0
    let peakLevel: Float
    var orientation: Orientation = .vertical
    var showClipping: Bool = true
    
    enum Orientation {
        case vertical, horizontal
    }
    
    private var clipping: Bool {
        peakLevel >= 0.95
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: orientation == .vertical ? .bottom : .leading) {
                // Background
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(.systemGray5))
                
                // Level fill
                RoundedRectangle(cornerRadius: 3)
                    .fill(levelGradient)
                    .frame(
                        width: orientation == .horizontal ? geo.size.width * CGFloat(level) : nil,
                        height: orientation == .vertical ? geo.size.height * CGFloat(level) : nil
                    )
                
                // Peak indicator
                if showClipping && clipping {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.red)
                        .frame(
                            width: orientation == .horizontal ? 4 : nil,
                            height: orientation == .vertical ? 4 : nil
                        )
                        .frame(
                            maxWidth: orientation == .vertical ? .infinity : nil,
                            maxHeight: orientation == .horizontal ? .infinity : nil
                        )
                        .position(
                            x: orientation == .horizontal ? geo.size.width * CGFloat(peakLevel) : geo.size.width / 2,
                            y: orientation == .vertical ? geo.size.height * (1 - CGFloat(peakLevel)) : geo.size.height / 2
                        )
                }
            }
        }
        .frame(width: orientation == .vertical ? 8 : nil, height: orientation == .horizontal ? 8 : nil)
    }
    
    private var levelGradient: LinearGradient {
        let colors: [Color] = [.green, .green, .yellow, .orange, .red]
        let startPoint: UnitPoint = orientation == .vertical ? .bottom : .leading
        let endPoint: UnitPoint = orientation == .vertical ? .top : .trailing
        return LinearGradient(colors: colors, startPoint: startPoint, endPoint: endPoint)
    }
}

/// Stereo meter pair
struct StereoMeterView: View {
    let leftLevel: Float
    let rightLevel: Float
    let leftPeak: Float
    let rightPeak: Float
    
    var body: some View {
        HStack(spacing: 2) {
            AudioLevelMeter(level: leftLevel, peakLevel: leftPeak)
            AudioLevelMeter(level: rightLevel, peakLevel: rightPeak)
        }
        .frame(width: 20)
    }
}
