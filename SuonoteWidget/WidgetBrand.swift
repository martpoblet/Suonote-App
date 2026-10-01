import SwiftUI
import WidgetKit

// MARK: - Brand tokens (mirrors the app's DesignSystem: ink on paper, teal pulse)

enum WidgetInk {
    static let paper = Color(light: 0xF5F2EB, dark: 0x0E0E0D)
    static let surface = Color(light: 0xF1EDE5, dark: 0x21211F)
    static let ink = Color(light: 0x171614, dark: 0xF3F0E9)
    static let inkSecondary = Color(light: 0x5E5A53, dark: 0xADA89E)
    static let inkTertiary = Color(light: 0x8F8A80, dark: 0x7A766D)
    static let rule = Color(light: 0xE2DDD2, dark: 0x2C2B28)
    static let brand = Color(light: 0x00CCBE, dark: 0x00CCBE)
    static let teal = Color(light: 0x00786F, dark: 0x5FE6DC)
    static let tealFill = Color(light: 0x00B5A8, dark: 0x1FD6C9)
    static let record = Color(light: 0xD9412E, dark: 0xFF6A55)

    static func status(_ raw: String) -> Color {
        switch raw {
        case "Idea": return Color(light: 0x4677AD, dark: 0x86B3E6)
        case "In Progress": return Color(light: 0xC2862A, dark: 0xE8B45E)
        case "Polished": return tealFill
        case "Finished": return Color(light: 0x3E9468, dark: 0x6FCB98)
        default: return Color(light: 0x8A857B, dark: 0x9C978D)
        }
    }

    /// Section colors are persisted as light hex values; the palette ones
    /// get their dark-mode partner like in the app.
    static func section(_ hex: String) -> Color {
        let clean = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")).uppercased()
        let darkPartner: [String: UInt32] = [
            "8FB096": 0x9DC4A6, "7A9ED3": 0x8FB3E8, "7FC7CF": 0x8FD9E2, "92C39A": 0xA1D4AA,
            "D8BD8B": 0xE2CB9D, "E09484": 0xEFA796, "C18ACB": 0xD29FDC, "A694D6": 0xB8A7E6,
        ]
        guard let light = UInt32(clean, radix: 16) else { return Color(light: 0x8FB096, dark: 0x9DC4A6) }
        return Color(light: light, dark: darkPartner[clean] ?? light)
    }
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        func ui(_ hex: UInt32) -> UIColor {
            UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                    blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        }
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? ui(dark) : ui(light) })
    }
}

/// Erode (serif, meaning) and Manrope (sans, mechanics) — the app's two voices.
/// Named instances of the variable fonts render real weights.
enum WidgetType {
    static func erode(_ size: CGFloat, _ weight: String = "Semibold", relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Erode-Variable-Light_\(weight)", size: size, relativeTo: style)
    }
    static func manrope(_ size: CGFloat, _ weight: String = "Medium", relativeTo style: Font.TextStyle = .caption) -> Font {
        .custom("Manrope-\(weight)", size: size, relativeTo: style)
    }
}

extension View {
    /// Small caps label, like the app's eyebrows ("CONTINUE", "KEY").
    func widgetEyebrow(_ color: Color = WidgetInk.inkTertiary) -> some View {
        self.font(WidgetType.manrope(9.5, "Bold", relativeTo: .caption2))
            .textCase(.uppercase)
            .tracking(1.0)
            .foregroundStyle(color)
    }
}

// MARK: - Logo waves (from the app's SuonoteLogoGeometry)

struct WidgetWavesMark: View {
    var height: CGFloat = 10
    var color: Color = WidgetInk.brand

    private static let lockup = CGSize(width: WidgetLogoGeometry.markWidth, height: WidgetLogoGeometry.size.height)

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                WidgetWave(index: index).fill(color)
            }
        }
        .frame(width: height * Self.lockup.width / Self.lockup.height, height: height)
        .accessibilityHidden(true)
    }
}

private struct WidgetWave: Shape {
    let index: Int
    func path(in rect: CGRect) -> Path {
        WidgetLogoGeometry.wave(index, in: rect,
                                lockup: CGSize(width: WidgetLogoGeometry.markWidth, height: WidgetLogoGeometry.size.height))
    }
}

/// The three waves of the Suonote logo (copied from the app target).
enum WidgetLogoGeometry {
    static let size = CGSize(width: 739.45, height: 104.00)
    static let markWidth: CGFloat = 146.96

    static func wave(_ index: Int, in rect: CGRect, lockup: CGSize = size) -> Path {
        var p = Path()
        let pt = mapper(rect, lockup)
        switch index {
        case 0:
            p.move(to: pt(141.990, 31.060))
            p.addCurve(to: pt(140.160, 30.710), control1: pt(141.380, 31.060), control2: pt(140.760, 30.950))
            p.addLine(to: pt(138.530, 30.060))
            p.addCurve(to: pt(131.110, 23.840), control1: pt(135.560, 28.880), control2: pt(133.000, 26.730))
            p.addLine(to: pt(124.260, 13.320))
            p.addCurve(to: pt(120.180, 10.630), control1: pt(123.170, 11.640), control2: pt(121.720, 10.690))
            p.addCurve(to: pt(116.160, 12.820), control1: pt(118.720, 10.590), control2: pt(117.290, 11.350))
            p.addLine(to: pt(108.950, 22.200))
            p.addCurve(to: pt(97.200, 28.270), control1: pt(105.980, 26.060), control2: pt(101.700, 28.270))
            p.addLine(to: pt(97.110, 28.270))
            p.addCurve(to: pt(85.320, 22.010), control1: pt(92.570, 28.240), control2: pt(88.270, 25.960))
            p.addLine(to: pt(77.970, 12.190))
            p.addCurve(to: pt(74.050, 9.920), control1: pt(76.880, 10.730), control2: pt(75.490, 9.920))
            p.addLine(to: pt(74.030, 9.920))
            p.addCurve(to: pt(70.140, 12.130), control1: pt(72.610, 9.920), control2: pt(71.230, 10.710))
            p.addLine(to: pt(62.440, 22.210))
            p.addCurve(to: pt(50.660, 28.330), control1: pt(59.470, 26.100), control2: pt(55.180, 28.330))
            p.addLine(to: pt(50.660, 28.330))
            p.addCurve(to: pt(38.880, 22.200), control1: pt(46.140, 28.330), control2: pt(41.840, 26.090))
            p.addLine(to: pt(31.330, 12.300))
            p.addCurve(to: pt(27.440, 10.080), control1: pt(30.240, 10.870), control2: pt(28.860, 10.080))
            p.addCurve(to: pt(27.400, 10.080), control1: pt(27.430, 10.080), control2: pt(27.410, 10.080))
            p.addCurve(to: pt(23.450, 12.440), control1: pt(25.940, 10.100), control2: pt(24.540, 10.930))
            p.addLine(to: pt(14.670, 24.530))
            p.addCurve(to: pt(7.940, 29.930), control1: pt(12.890, 26.980), control2: pt(10.560, 28.850))
            p.addLine(to: pt(6.850, 30.380))
            p.addCurve(to: pt(0.370, 27.680), control1: pt(4.310, 31.420), control2: pt(1.410, 30.210))
            p.addCurve(to: pt(3.070, 21.200), control1: pt(-0.670, 25.140), control2: pt(0.540, 22.240))
            p.addLine(to: pt(4.160, 20.750))
            p.addCurve(to: pt(6.630, 18.700), control1: pt(5.080, 20.370), control2: pt(5.930, 19.660))
            p.addLine(to: pt(15.420, 6.610))
            p.addCurve(to: pt(27.300, 0.160), control1: pt(18.360, 2.570), control2: pt(22.690, 0.220))
            p.addCurve(to: pt(27.460, 0.160), control1: pt(27.350, 0.160), control2: pt(27.410, 0.160))
            p.addCurve(to: pt(39.250, 6.290), control1: pt(31.990, 0.160), control2: pt(36.280, 2.390))
            p.addLine(to: pt(46.800, 16.190))
            p.addCurve(to: pt(50.690, 18.410), control1: pt(47.890, 17.620), control2: pt(49.270, 18.410))
            p.addLine(to: pt(50.690, 18.410))
            p.addCurve(to: pt(54.580, 16.200), control1: pt(52.110, 18.410), control2: pt(53.490, 17.620))
            p.addLine(to: pt(62.280, 6.120))
            p.addCurve(to: pt(74.060, -0.000), control1: pt(65.250, 2.230), control2: pt(69.540, -0.000))
            p.addLine(to: pt(74.130, -0.000))
            p.addCurve(to: pt(85.950, 6.260), control1: pt(78.680, 0.020), control2: pt(82.990, 2.300))
            p.addLine(to: pt(93.300, 16.080))
            p.addCurve(to: pt(97.210, 18.350), control1: pt(94.390, 17.540), control2: pt(95.780, 18.340))
            p.addLine(to: pt(97.240, 18.350))
            p.addCurve(to: pt(101.110, 16.160), control1: pt(98.650, 18.350), control2: pt(100.020, 17.570))
            p.addLine(to: pt(108.320, 6.780))
            p.addCurve(to: pt(120.600, 0.720), control1: pt(111.420, 2.740), control2: pt(115.920, 0.520))
            p.addCurve(to: pt(132.610, 7.920), control1: pt(125.380, 0.910), control2: pt(129.760, 3.530))
            p.addLine(to: pt(139.460, 18.440))
            p.addCurve(to: pt(142.210, 20.850), control1: pt(140.210, 19.600), control2: pt(141.170, 20.430))
            p.addLine(to: pt(143.840, 21.500))
            p.addCurve(to: pt(146.630, 27.950), control1: pt(146.390, 22.510), control2: pt(147.640, 25.400))
            p.addCurve(to: pt(142.010, 31.090), control1: pt(145.860, 29.900), control2: pt(143.990, 31.090))
            p.closeSubpath()
        case 1:
            p.move(to: pt(141.990, 67.530))
            p.addCurve(to: pt(140.160, 67.180), control1: pt(141.380, 67.530), control2: pt(140.760, 67.420))
            p.addLine(to: pt(138.530, 66.530))
            p.addCurve(to: pt(131.110, 60.310), control1: pt(135.560, 65.350), control2: pt(132.990, 63.200))
            p.addLine(to: pt(124.260, 49.790))
            p.addCurve(to: pt(120.180, 47.100), control1: pt(123.170, 48.120), control2: pt(121.720, 47.160))
            p.addCurve(to: pt(116.160, 49.290), control1: pt(118.720, 47.060), control2: pt(117.290, 47.820))
            p.addLine(to: pt(108.950, 58.670))
            p.addCurve(to: pt(97.200, 64.740), control1: pt(105.980, 62.530), control2: pt(101.700, 64.740))
            p.addLine(to: pt(97.110, 64.740))
            p.addCurve(to: pt(85.320, 58.480), control1: pt(92.570, 64.710), control2: pt(88.270, 62.430))
            p.addLine(to: pt(77.970, 48.660))
            p.addCurve(to: pt(74.060, 46.390), control1: pt(76.880, 47.200), control2: pt(75.490, 46.390))
            p.addCurve(to: pt(70.150, 48.600), control1: pt(72.600, 46.380), control2: pt(71.250, 47.170))
            p.addLine(to: pt(62.450, 58.680))
            p.addCurve(to: pt(50.670, 64.800), control1: pt(59.480, 62.570), control2: pt(55.190, 64.800))
            p.addLine(to: pt(50.670, 64.800))
            p.addCurve(to: pt(38.890, 58.670), control1: pt(46.150, 64.800), control2: pt(41.850, 62.560))
            p.addLine(to: pt(31.340, 48.770))
            p.addCurve(to: pt(27.450, 46.550), control1: pt(30.250, 47.340), control2: pt(28.870, 46.550))
            p.addCurve(to: pt(27.410, 46.550), control1: pt(27.440, 46.550), control2: pt(27.420, 46.550))
            p.addCurve(to: pt(23.460, 48.910), control1: pt(25.950, 46.570), control2: pt(24.550, 47.400))
            p.addLine(to: pt(14.680, 61.000))
            p.addCurve(to: pt(7.950, 66.400), control1: pt(12.900, 63.450), control2: pt(10.570, 65.320))
            p.addLine(to: pt(6.860, 66.850))
            p.addCurve(to: pt(0.380, 64.150), control1: pt(4.320, 67.890), control2: pt(1.420, 66.680))
            p.addCurve(to: pt(3.080, 57.670), control1: pt(-0.660, 61.610), control2: pt(0.550, 58.710))
            p.addLine(to: pt(4.170, 57.220))
            p.addCurve(to: pt(6.640, 55.170), control1: pt(5.090, 56.840), control2: pt(5.940, 56.130))
            p.addLine(to: pt(15.420, 43.080))
            p.addCurve(to: pt(27.290, 36.630), control1: pt(18.360, 39.030), control2: pt(22.690, 36.680))
            p.addCurve(to: pt(27.450, 36.630), control1: pt(27.340, 36.630), control2: pt(27.400, 36.630))
            p.addCurve(to: pt(39.240, 42.760), control1: pt(31.980, 36.630), control2: pt(36.260, 38.860))
            p.addLine(to: pt(46.790, 52.660))
            p.addCurve(to: pt(50.680, 54.880), control1: pt(47.880, 54.090), control2: pt(49.260, 54.880))
            p.addLine(to: pt(50.680, 54.880))
            p.addCurve(to: pt(54.570, 52.670), control1: pt(52.100, 54.880), control2: pt(53.480, 54.090))
            p.addLine(to: pt(62.270, 42.590))
            p.addCurve(to: pt(74.050, 36.470), control1: pt(65.240, 38.700), control2: pt(69.530, 36.470))
            p.addCurve(to: pt(74.120, 36.470), control1: pt(74.070, 36.470), control2: pt(74.090, 36.470))
            p.addCurve(to: pt(85.940, 42.730), control1: pt(78.670, 36.490), control2: pt(82.980, 38.770))
            p.addLine(to: pt(93.290, 52.550))
            p.addCurve(to: pt(97.200, 54.820), control1: pt(94.380, 54.010), control2: pt(95.770, 54.810))
            p.addLine(to: pt(97.230, 54.820))
            p.addCurve(to: pt(101.100, 52.630), control1: pt(98.640, 54.820), control2: pt(100.010, 54.040))
            p.addLine(to: pt(108.310, 43.250))
            p.addCurve(to: pt(120.590, 37.190), control1: pt(111.410, 39.210), control2: pt(115.880, 36.990))
            p.addCurve(to: pt(132.600, 44.390), control1: pt(125.370, 37.380), control2: pt(129.750, 40.000))
            p.addLine(to: pt(139.450, 54.910))
            p.addCurve(to: pt(142.200, 57.320), control1: pt(140.200, 56.070), control2: pt(141.160, 56.900))
            p.addLine(to: pt(143.830, 57.970))
            p.addCurve(to: pt(146.620, 64.420), control1: pt(146.380, 58.980), control2: pt(147.630, 61.870))
            p.addCurve(to: pt(142.000, 67.560), control1: pt(145.850, 66.370), control2: pt(143.980, 67.560))
            p.closeSubpath()
        case 2:
            p.move(to: pt(141.990, 104.000))
            p.addCurve(to: pt(140.160, 103.650), control1: pt(141.380, 104.000), control2: pt(140.760, 103.890))
            p.addLine(to: pt(138.530, 103.000))
            p.addCurve(to: pt(131.110, 96.780), control1: pt(135.560, 101.820), control2: pt(132.990, 99.670))
            p.addLine(to: pt(124.260, 86.260))
            p.addCurve(to: pt(120.180, 83.570), control1: pt(123.170, 84.590), control2: pt(121.720, 83.630))
            p.addCurve(to: pt(116.160, 85.760), control1: pt(118.690, 83.510), control2: pt(117.290, 84.290))
            p.addLine(to: pt(108.950, 95.140))
            p.addCurve(to: pt(97.200, 101.210), control1: pt(105.980, 99.000), control2: pt(101.700, 101.210))
            p.addLine(to: pt(97.110, 101.210))
            p.addCurve(to: pt(85.320, 94.950), control1: pt(92.570, 101.180), control2: pt(88.270, 98.900))
            p.addLine(to: pt(77.970, 85.130))
            p.addCurve(to: pt(74.060, 82.860), control1: pt(76.880, 83.670), control2: pt(75.490, 82.860))
            p.addCurve(to: pt(70.150, 85.070), control1: pt(72.620, 82.870), control2: pt(71.250, 83.640))
            p.addLine(to: pt(62.450, 95.150))
            p.addCurve(to: pt(50.670, 101.270), control1: pt(59.480, 99.040), control2: pt(55.190, 101.270))
            p.addLine(to: pt(50.670, 101.270))
            p.addCurve(to: pt(38.890, 95.140), control1: pt(46.150, 101.270), control2: pt(41.850, 99.030))
            p.addLine(to: pt(31.340, 85.240))
            p.addCurve(to: pt(27.450, 83.020), control1: pt(30.250, 83.810), control2: pt(28.870, 83.020))
            p.addLine(to: pt(27.410, 83.020))
            p.addCurve(to: pt(23.460, 85.380), control1: pt(25.950, 83.040), control2: pt(24.550, 83.870))
            p.addLine(to: pt(14.680, 97.470))
            p.addCurve(to: pt(7.950, 102.870), control1: pt(12.900, 99.920), control2: pt(10.570, 101.790))
            p.addLine(to: pt(6.860, 103.320))
            p.addCurve(to: pt(0.380, 100.620), control1: pt(4.320, 104.360), control2: pt(1.420, 103.150))
            p.addCurve(to: pt(3.080, 94.140), control1: pt(-0.660, 98.080), control2: pt(0.550, 95.180))
            p.addLine(to: pt(4.170, 93.690))
            p.addCurve(to: pt(6.640, 91.640), control1: pt(5.090, 93.310), control2: pt(5.940, 92.600))
            p.addLine(to: pt(15.420, 79.550))
            p.addCurve(to: pt(27.290, 73.100), control1: pt(18.360, 75.500), control2: pt(22.690, 73.150))
            p.addCurve(to: pt(27.450, 73.100), control1: pt(27.340, 73.100), control2: pt(27.400, 73.100))
            p.addCurve(to: pt(39.240, 79.230), control1: pt(31.980, 73.100), control2: pt(36.270, 75.330))
            p.addLine(to: pt(46.790, 89.130))
            p.addCurve(to: pt(50.680, 91.350), control1: pt(47.880, 90.560), control2: pt(49.260, 91.350))
            p.addLine(to: pt(50.680, 91.350))
            p.addCurve(to: pt(54.570, 89.140), control1: pt(52.100, 91.350), control2: pt(53.480, 90.560))
            p.addLine(to: pt(62.270, 79.060))
            p.addCurve(to: pt(74.050, 72.940), control1: pt(65.240, 75.170), control2: pt(69.530, 72.940))
            p.addLine(to: pt(74.120, 72.940))
            p.addCurve(to: pt(85.940, 79.200), control1: pt(78.670, 72.960), control2: pt(82.980, 75.240))
            p.addLine(to: pt(93.290, 89.020))
            p.addCurve(to: pt(97.200, 91.290), control1: pt(94.380, 90.480), control2: pt(95.770, 91.280))
            p.addCurve(to: pt(101.100, 89.100), control1: pt(98.590, 91.290), control2: pt(100.000, 90.520))
            p.addLine(to: pt(108.310, 79.720))
            p.addCurve(to: pt(120.590, 73.660), control1: pt(111.410, 75.680), control2: pt(115.890, 73.470))
            p.addCurve(to: pt(132.600, 80.860), control1: pt(125.370, 73.850), control2: pt(129.750, 76.470))
            p.addLine(to: pt(139.450, 91.380))
            p.addCurve(to: pt(142.200, 93.790), control1: pt(140.200, 92.540), control2: pt(141.160, 93.370))
            p.addLine(to: pt(143.830, 94.440))
            p.addCurve(to: pt(146.620, 100.890), control1: pt(146.380, 95.450), control2: pt(147.630, 98.340))
            p.addCurve(to: pt(142.000, 104.030), control1: pt(145.850, 102.840), control2: pt(143.980, 104.030))
            p.closeSubpath()
        default: break
        }
        return p
    }

    /// Maps SVG coordinates into `rect`, preserving aspect ratio (fit, centered).
    private static func mapper(_ rect: CGRect, _ lockup: CGSize) -> (CGFloat, CGFloat) -> CGPoint {
        let scale = min(rect.width / lockup.width, rect.height / lockup.height)
        let dx = rect.minX + (rect.width - lockup.width * scale) / 2
        let dy = rect.minY + (rect.height - lockup.height * scale) / 2
        return { x, y in CGPoint(x: dx + x * scale, y: dy + y * scale) }
    }
}
