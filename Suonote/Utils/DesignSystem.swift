import SwiftUI

// MARK: - Design System
/// Suonote — "ink on paper, with a teal pulse".
///
/// The look is an editorial music notebook: warm paper surfaces, near-black
/// ink, hairline rules, Erode serif for anything that carries meaning (titles,
/// chord names, section names, numbers) and Manrope for the working UI.
/// The brand teal (#00CCBE, the logo's waves) is the single accent — used for
/// what is *alive* (playing, selected, primary action), never as decoration.
///
/// Liquid Glass (iOS 26) is reserved for the floating control layer
/// (tab bar, transport, toolbars, FABs). Content surfaces stay solid paper.

struct DesignSystem {

    // MARK: - Colors

    struct Colors {
        // Brand
        /// Exact logo teal. Use for brand marks, waves, active meters.
        static let brand = Color(light: "00CCBE", dark: "00CCBE")
        /// Teal for fills (buttons, selected chips, playheads).
        static let primary = Color(light: "00B5A8", dark: "1FD6C9")
        static let primaryLight = Color(light: "D6F4F1", dark: "123532")
        /// Teal for text & icons on paper (AA contrast).
        static let primaryDark = Color(light: "00786F", dark: "5FE6DC")
        /// Warm terracotta — the brand's second voice (recording, highlights).
        static let accent = Color(light: "D26A47", dark: "EE8C69")

        // Backgrounds (paper)
        static let background = Color(light: "F5F2EB", dark: "0E0E0D")
        static let backgroundSecondary = Color(light: "FBF9F5", dark: "151514")
        static let backgroundTertiary = Color(light: "EDE9E0", dark: "1B1B19")

        // Surfaces (cards sit on the paper)
        static let surface = Color(light: "FFFEFB", dark: "1A1A18")
        static let surfaceSecondary = Color(light: "F1EDE5", dark: "21211F")
        static let surfaceHover = Color(light: "EAE5DB", dark: "292926")
        static let surfaceActive = Color(light: "E1DBCF", dark: "32322E")

        // Ink
        static let textPrimary = Color(light: "171614", dark: "F3F0E9")
        static let textSecondary = Color(light: "5E5A53", dark: "ADA89E")
        static let textTertiary = Color(light: "8F8A80", dark: "7A766D")
        static let textWhite = Color(light: "FFFFFF", dark: "FFFFFF")
        static let textMuted = Color(light: "A9A398", dark: "6A665E")
        /// Text placed on a `primary` fill.
        static let onPrimary = Color(light: "FFFFFF", dark: "08201E")

        // Rules
        static let border = Color(light: "E2DDD2", dark: "2C2B28")
        static let borderActive = Color(light: "C9C2B4", dark: "47453F")
        static let borderSubtle = Color(light: "ECE8DF", dark: "232220")

        // Status
        static let success = Color(light: "3E9468", dark: "6FCB98")
        static let warning = Color(light: "C2862A", dark: "E8B45E")
        static let error = Color(light: "C4513A", dark: "EE826B")
        static let info = Color(light: "4677AD", dark: "86B3E6")
        static let secondary = Color(light: "8A857B", dark: "9C978D")
        /// Recording red.
        static let record = Color(light: "D9412E", dark: "FF6A55")

        // Section Palette (used across chips, tabs, and tags)
        // Raw hex values are persisted in models; keep them stable.
        static let sectionSageHex = "8FB096"
        static let sectionOceanHex = "7A9ED3"
        static let sectionSkyHex = "7FC7CF"
        static let sectionMossHex = "92C39A"
        static let sectionSandHex = "D8BD8B"
        static let sectionCoralHex = "E09484"
        static let sectionBerryHex = "C18ACB"
        static let sectionLavenderHex = "A694D6"

        static let sectionSage = Color(light: sectionSageHex, dark: "9DC4A6")
        static let sectionOcean = Color(light: sectionOceanHex, dark: "8FB3E8")
        static let sectionSky = Color(light: sectionSkyHex, dark: "8FD9E2")
        static let sectionMoss = Color(light: sectionMossHex, dark: "A1D4AA")
        static let sectionSand = Color(light: sectionSandHex, dark: "E2CB9D")
        static let sectionCoral = Color(light: sectionCoralHex, dark: "EFA796")
        static let sectionBerry = Color(light: sectionBerryHex, dark: "D29FDC")
        static let sectionLavender = Color(light: sectionLavenderHex, dark: "B8A7E6")

        // Tab Bar
        static let tabBarBackground = background
        static let tabBarActive = primaryDark
        static let tabBarInactive = textSecondary
    }

    // MARK: - Typography
    /// One scale, two voices. Erode = meaning, Manrope = mechanics.
    /// Never use Erode below 15 pt; never use Manrope for a screen title.

    struct Typography {
        // Display — Erode. Hero numbers & screen titles.
        static let displayLarge = Font.erode(48, weight: .semibold, relativeTo: .largeTitle)
        static let display = Font.erode(40, weight: .semibold, relativeTo: .largeTitle)
        static let largeTitle = Font.erode(34, weight: .semibold, relativeTo: .largeTitle)
        static let title = Font.erode(28, weight: .semibold, relativeTo: .title)
        static let title2 = Font.erode(23, weight: .semibold, relativeTo: .title2)
        static let title3 = Font.erode(20, weight: .semibold, relativeTo: .title3)
        /// Card / row titles (project names, section names, track names).
        static let headline = Font.erode(17, weight: .semibold, relativeTo: .headline)

        /// Editorial italic — subtitles, empty-state lines, quotes.
        static let italic = Font.erodeItalic(17, weight: .regular, relativeTo: .body)
        static let italicLarge = Font.erodeItalic(22, weight: .regular, relativeTo: .title3)
        static let italicSmall = Font.erodeItalic(15, weight: .regular, relativeTo: .subheadline)

        /// Musical tokens — chord symbols, keys, BPM figures.
        static let chord = Font.erode(20, weight: .semibold, relativeTo: .title3)
        static let chordSmall = Font.erode(16, weight: .semibold, relativeTo: .callout)
        static let numeric = Font.erode(28, weight: .medium, relativeTo: .title)

        // Working UI — Manrope.
        /// UI labels, list rows, button titles.
        static let subheadline = Font.manrope(15, weight: .semibold, relativeTo: .subheadline)
        static let body = Font.manrope(15, weight: .regular, relativeTo: .body)
        static let bodyMedium = Font.manrope(15, weight: .medium, relativeTo: .body)
        static let bodyBold = Font.manrope(15, weight: .semibold, relativeTo: .body)
        static let callout = Font.manrope(14, weight: .regular, relativeTo: .callout)
        static let calloutBold = Font.manrope(14, weight: .semibold, relativeTo: .callout)
        static let footnote = Font.manrope(13, weight: .regular, relativeTo: .footnote)
        static let caption = Font.manrope(12, weight: .medium, relativeTo: .caption)
        static let caption2 = Font.manrope(11, weight: .medium, relativeTo: .caption2)
        static let micro = Font.manrope(10, weight: .semibold, relativeTo: .caption2)
        static let nano = Font.manrope(9, weight: .bold, relativeTo: .caption2)
        /// Small-caps style label above a group ("ARRANGEMENT", "TRACKS").
        /// Pair with `.eyebrow()` for tracking + uppercase.
        static let eyebrow = Font.manrope(11, weight: .bold, relativeTo: .caption2)
        static let button = Font.manrope(15, weight: .semibold, relativeTo: .body)
        static let buttonSmall = Font.manrope(13, weight: .semibold, relativeTo: .footnote)

        // Large display sizes (Erode) — kept for hero moments.
        static let hero = Font.erode(112, weight: .semibold, relativeTo: .largeTitle)
        static let mega = Font.erode(72, weight: .semibold, relativeTo: .largeTitle)
        static let jumbo = Font.erode(60, weight: .semibold, relativeTo: .largeTitle)
        static let giant = Font.erode(56, weight: .semibold, relativeTo: .largeTitle)
        static let huge = Font.erode(48, weight: .semibold, relativeTo: .largeTitle)
        static let xxl = Font.erode(44, weight: .medium, relativeTo: .largeTitle)
        static let xl = Font.erode(40, weight: .medium, relativeTo: .largeTitle)
        static let lg = Font.erode(36, weight: .medium, relativeTo: .title)
        static let md = Font.erode(32, weight: .medium, relativeTo: .title)
        static let sm = Font.erode(24, weight: .medium, relativeTo: .title2)

        // Special
        static let monospaced = Font.system(.body, design: .monospaced)
        /// Timecode / bar.beat counters.
        static let timecode = Font.manrope(15, weight: .semibold, relativeTo: .body).monospacedDigit()
    }

    // MARK: - Spacing

    struct Spacing {
        static let xxxs: CGFloat = 2
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 40
        /// Horizontal screen gutter.
        static let gutter: CGFloat = 20
    }

    // MARK: - Corner Radius

    struct CornerRadius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
        static let round: CGFloat = 999
        /// Default content card.
        static let card: CGFloat = 18
    }

    // MARK: - Animations

    struct Animations {
        static let quickSpring = Animation.spring(response: 0.3, dampingFraction: 0.75)
        static let smoothSpring = Animation.spring(response: 0.42, dampingFraction: 0.82)
        static let gentleSpring = Animation.spring(response: 0.55, dampingFraction: 0.9)
        static let bouncy = Animation.spring(response: 0.38, dampingFraction: 0.62)

        static let quickEase = Animation.easeInOut(duration: 0.2)
        static let smoothEase = Animation.easeInOut(duration: 0.3)
        static let gentleEase = Animation.easeInOut(duration: 0.4)
    }

    // MARK: - Icons

    struct Icons {
        static let chord = "music.note"
        static let chords = "music.note.list"
        static let key = "music.note"
        static let tempo = "metronome"
        static let timeSignature = "clock"
        static let waveform = "waveform"

        static let add = "plus"
        static let delete = "trash"
        static let edit = "pencil"
        static let duplicate = "doc.on.doc"
        static let export = "square.and.arrow.up"

        static let play = "play.fill"
        static let pause = "pause.fill"
        static let stop = "stop.fill"
        static let record = "record.circle"

        static let chevronUp = "chevron.up"
        static let chevronDown = "chevron.down"
        static let chevronLeft = "chevron.left"
        static let chevronRight = "chevron.right"
    }
}

// MARK: - Adaptive Color Support

extension Color {
    /// Adaptive color that resolves a different hex per interface style.
    init(light: String, dark: String) {
        self.init(uiColor: UIColor { trait in
            UIColor(hexString: trait.userInterfaceStyle == .dark ? dark : light)
        })
    }

    init(hexNonOptional hex: String) {
        self.init(uiColor: UIColor(hexString: hex))
    }
}

extension UIColor {
    convenience init(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}

// MARK: - Buttons

struct PrimaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    let isDestructive: Bool

    init(_ title: String, icon: String? = nil, isDestructive: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
        self.isDestructive = isDestructive
    }

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: DesignSystem.Spacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(title)
                    .font(DesignSystem.Typography.button)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(BrandButtonStyle(tint: isDestructive ? DesignSystem.Colors.error : DesignSystem.Colors.primary))
    }
}

/// Full-width primary CTA: solid brand teal capsule, paper-white label.
/// Solid (not glass) so the one action that matters is unmistakable on any
/// background; disabled state fades to a quiet well.
struct BrandButtonStyle: ButtonStyle {
    var tint: Color = DesignSystem.Colors.primary
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isEnabled ? DesignSystem.Colors.onPrimary : DesignSystem.Colors.textTertiary)
            .padding(.vertical, 15)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .background(
                Capsule(style: .continuous)
                    .fill(isEnabled ? tint : DesignSystem.Colors.surfaceSecondary)
                    .shadow(color: isEnabled ? tint.opacity(0.28) : .clear, radius: 12, x: 0, y: 6)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(DesignSystem.Animations.quickSpring, value: configuration.isPressed)
    }
}

struct SecondaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: DesignSystem.Spacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                }
                Text(title)
                    .font(DesignSystem.Typography.buttonSmall)
            }
            .foregroundStyle(DesignSystem.Colors.textPrimary)
            .padding(.horizontal, DesignSystem.Spacing.xxs)
            .padding(.vertical, DesignSystem.Spacing.xxxs)
        }
        .buttonStyle(.glass)
    }
}

enum AppButtonKind {
    case primary(Color)
    case secondary
    case destructive
}

struct AppButton: View {
    let title: String
    var icon: String? = nil
    var kind: AppButtonKind = .primary(DesignSystem.Colors.primary)
    let action: () -> Void

    var body: some View {
        switch kind {
        case .primary(let color):
            baseButton
                .buttonStyle(BrandButtonStyle(tint: color))
        case .secondary:
            baseButton
                .buttonStyle(OutlineButtonStyle())
        case .destructive:
            baseButton
                .buttonStyle(BrandButtonStyle(tint: DesignSystem.Colors.error))
        }
    }

    private var baseButton: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(title)
            }
            .font(DesignSystem.Typography.button)
            .frame(maxWidth: .infinity)
        }
    }
}

/// Solid ink/teal capsule button for content areas (not floating).
struct InkButtonStyle: ButtonStyle {
    var tint: Color = DesignSystem.Colors.textPrimary
    var foreground: Color = DesignSystem.Colors.background
    var compact: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(compact ? DesignSystem.Typography.buttonSmall : DesignSystem.Typography.button)
            .foregroundStyle(foreground)
            .padding(.horizontal, compact ? 14 : 20)
            .padding(.vertical, compact ? 8 : 13)
            .background(Capsule().fill(tint))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(DesignSystem.Animations.quickSpring, value: configuration.isPressed)
    }
}

/// Hairline outlined capsule — quiet secondary action inside content.
struct OutlineButtonStyle: ButtonStyle {
    var tint: Color = DesignSystem.Colors.textPrimary
    var compact: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(compact ? DesignSystem.Typography.buttonSmall : DesignSystem.Typography.button)
            .foregroundStyle(tint)
            .padding(.horizontal, compact ? 14 : 20)
            .padding(.vertical, compact ? 8 : 12)
            .background(
                Capsule()
                    .fill(configuration.isPressed ? DesignSystem.Colors.surfaceHover : DesignSystem.Colors.surface)
            )
            .overlay(Capsule().stroke(DesignSystem.Colors.borderActive, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(DesignSystem.Animations.quickSpring, value: configuration.isPressed)
    }
}

// MARK: - Badges & Chips

struct Badge: View {
    let text: String
    let color: Color

    init(_ text: String, color: Color = DesignSystem.Colors.primary) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(DesignSystem.Typography.caption2)
            .foregroundStyle(color)
            .padding(.horizontal, DesignSystem.Spacing.xs)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.13)))
    }
}

struct AppChip: View {
    let text: String
    var icon: String? = nil
    var tint: Color = DesignSystem.Colors.primary
    var textColor: Color = DesignSystem.Colors.textPrimary
    var fillOpacity: Double = 0.14
    var strokeOpacity: Double = 0.0
    var font: Font = DesignSystem.Typography.caption

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xxs) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(tint)
            }
            Text(text)
                .font(font)
                .foregroundStyle(textColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(tint.opacity(fillOpacity))
                .overlay(
                    Capsule()
                        .stroke(tint.opacity(strokeOpacity), lineWidth: strokeOpacity > 0 ? 1 : 0)
                )
        )
    }
}

/// Selectable filter/option chip: ink when selected, paper when not.
struct SelectableChip: View {
    let title: String
    var icon: String? = nil
    var dot: Color? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let dot {
                    Circle().fill(dot).frame(width: 7, height: 7)
                }
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(title)
                    .font(DesignSystem.Typography.buttonSmall)
            }
            .foregroundStyle(isSelected ? DesignSystem.Colors.background : DesignSystem.Colors.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(isSelected ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.surface)
            )
            .overlay(
                Capsule().stroke(isSelected ? Color.clear : DesignSystem.Colors.border, lineWidth: 1)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(DesignSystem.Animations.quickSpring, value: isSelected)
    }
}

// MARK: - Editorial Building Blocks

/// Screen-level editorial header: small eyebrow, big Erode title, italic line.
struct ScreenHeader<Trailing: View>: View {
    var eyebrow: String? = nil
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .bottom, spacing: DesignSystem.Spacing.sm) {
            VStack(alignment: .leading, spacing: 6) {
                if let eyebrow {
                    Text(eyebrow)
                        .eyebrow()
                }
                Text(title)
                    .font(DesignSystem.Typography.largeTitle)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                if let subtitle {
                    Text(subtitle)
                        .font(DesignSystem.Typography.italicSmall)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
            Spacer(minLength: 0)
            trailing
        }
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(eyebrow: String? = nil, title: String, subtitle: String? = nil) {
        self.init(eyebrow: eyebrow, title: title, subtitle: subtitle) { EmptyView() }
    }
}

/// Group header inside a screen: eyebrow label + optional trailing action.
struct SectionHeader: View {
    let title: String
    var detail: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.xs) {
            Text(title)
                .eyebrow()
            if let detail {
                Text(detail)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
            Spacer(minLength: 0)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(DesignSystem.Typography.buttonSmall)
                    .foregroundStyle(DesignSystem.Colors.primaryDark)
            }
        }
    }
}

/// A musical fact (Key, BPM, Meter) set in Erode numerals with a small label.
struct StatTile: View {
    let label: String
    let value: String
    var icon: String? = nil
    var tint: Color = DesignSystem.Colors.textPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 9, weight: .bold))
                }
                Text(label)
            }
            .eyebrow()
            // Longer translations ("TONALIDAD", "COMPASES") shrink instead of
            // breaking mid-word in narrow four-up rows.
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .allowsTightening(true)
            Text(value)
                .font(DesignSystem.Typography.title2)
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Thin horizontal rule in the paper's ink.
struct Hairline: View {
    var color: Color = DesignSystem.Colors.border
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: 1 / displayScale)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Brand Waves

/// The three-wave mark from the Suonote logo, as a strokable shape.
/// Use for empty states, splash, and quiet decoration.
struct BrandWaves: Shape {
    var rows: Int = 3
    var peaks: Int = 3
    /// 0...1 horizontal phase shift, animatable for a gentle "breathing" loop.
    var phase: CGFloat = 0

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard rows > 0, peaks > 0 else { return path }
        let rowSpacing = rect.height / CGFloat(rows)
        let amplitude = min(rowSpacing * 0.3, rect.width * 0.08)
        for row in 0..<rows {
            let baseY = rect.minY + rowSpacing * (CGFloat(row) + 0.5)
            let steps = 60
            for step in 0...steps {
                let t = CGFloat(step) / CGFloat(steps)
                let x = rect.minX + t * rect.width
                let angle = (t * CGFloat(peaks) + phase) * 2 * .pi
                let y = baseY - sin(angle) * amplitude
                if step == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
        return path
    }
}

/// The original logo waves (brand geometry) in teal. When `animated`, the
/// three waves "breathe" in sequence — their amplitude swells and settles one
/// after another, like a soft level meter — instead of sliding sideways.
/// Static under Reduce Motion.
struct BrandWavesMark: View {
    var size: CGFloat = 44
    var color: Color = DesignSystem.Colors.brand
    var animated: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let markLockup = CGSize(
        width: SuonoteLogoGeometry.markWidth,
        height: SuonoteLogoGeometry.size.height
    )

    var body: some View {
        Group {
            if animated && !reduceMotion {
                TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                    waves(time: context.date.timeIntervalSinceReferenceDate)
                }
            } else {
                waves(time: nil)
            }
        }
        .frame(width: size * Self.markLockup.width / Self.markLockup.height, height: size)
        .accessibilityHidden(true)
    }

    private func waves(time: TimeInterval?) -> some View {
        ZStack {
            ForEach(0..<SuonoteLogoGeometry.waveCount, id: \.self) { index in
                let swell = swell(index: index, time: time)
                MarkWave(index: index, lockup: Self.markLockup)
                    .fill(color)
                    .scaleEffect(x: 1, y: swell, anchor: anchor(for: index))
                    .opacity(0.72 + 0.28 * Double(swell))
            }
        }
    }

    /// 0.62…1.0, a smooth pulse travelling top → bottom (2.4 s cycle).
    private func swell(index: Int, time: TimeInterval?) -> CGFloat {
        guard let time else { return 1 }
        let phase = (time / 2.4 - Double(index) * 0.18) * 2 * .pi
        let wave = (sin(phase) + 1) / 2          // 0…1
        let eased = wave * wave * (3 - 2 * wave) // smoothstep
        return CGFloat(0.62 + 0.38 * eased)
    }

    /// Each wave breathes around its own centre line.
    private func anchor(for index: Int) -> UnitPoint {
        let centers: [CGFloat] = [0.2, 0.5, 0.8]
        return UnitPoint(x: 0.5, y: centers[min(index, centers.count - 1)])
    }

    private struct MarkWave: Shape {
        let index: Int
        let lockup: CGSize
        func path(in rect: CGRect) -> Path {
            SuonoteLogoGeometry.wave(index, in: rect, lockup: lockup)
        }
    }
}

// MARK: - States

struct LoadingView: View {
    let message: String

    init(_ message: String = String(localized: "Loading…")) {
        self.message = message
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            BrandWavesMark(size: 30, animated: true)
            Text(message)
                .font(DesignSystem.Typography.italicSmall)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
        .padding(DesignSystem.Spacing.xxl)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(icon: String, title: String, message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.primaryLight)
                    .frame(width: 84, height: 84)
                Image(systemName: icon)
                    .font(.system(size: 30, weight: .regular))
                    .foregroundStyle(DesignSystem.Colors.primaryDark)
            }

            VStack(spacing: DesignSystem.Spacing.xs) {
                Text(title)
                    .font(DesignSystem.Typography.title2)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(DesignSystem.Typography.italicSmall)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 320)

            if let actionTitle, let action {
                Button(action: action) {
                    Label(actionTitle, systemImage: DesignSystem.Icons.add)
                }
                .buttonStyle(InkButtonStyle())
            }
        }
        .padding(DesignSystem.Spacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Section Color Indicator

struct SectionColorDot: View {
    let color: Color
    let size: CGFloat

    init(_ color: Color, size: CGFloat = 12) {
        self.color = color
        self.size = size
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
    }
}

// MARK: - View Extensions

extension View {
    /// Solid paper card. Content stays opaque for legibility;
    /// Liquid Glass is reserved for floating controls.
    func cardStyle(
        cornerRadius: CGFloat = DesignSystem.CornerRadius.card,
        color: Color? = nil,
        fill: Color = DesignSystem.Colors.surface
    ) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
                    .shadow(color: Color.black.opacity(0.035), radius: 10, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(color ?? DesignSystem.Colors.border, lineWidth: 1)
            )
    }

    /// Recessed well (inputs, grids, inactive areas).
    func wellStyle(cornerRadius: CGFloat = DesignSystem.CornerRadius.md) -> some View {
        self.background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(DesignSystem.Colors.surfaceSecondary)
        )
    }

    func pillStyle() -> some View {
        self
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(
                Capsule()
                    .fill(DesignSystem.Colors.surface)
                    .overlay(
                        Capsule().stroke(DesignSystem.Colors.border, lineWidth: 1)
                    )
            )
    }

    /// Uppercase, tracked Manrope label used above groups of content.
    func eyebrow(color: Color = DesignSystem.Colors.textTertiary) -> some View {
        self
            .font(DesignSystem.Typography.eyebrow)
            .textCase(.uppercase)
            .tracking(1.1)
            .foregroundStyle(color)
    }

    /// Paper background for a full screen.
    func paperBackground() -> some View {
        self.background(DesignSystem.Colors.background.ignoresSafeArea())
    }

    func animatedPress(scale: CGFloat = 0.97) -> some View {
        self.buttonStyle(AnimatedPressButtonStyle(scale: scale))
    }
}

struct AnimatedPressButtonStyle: ButtonStyle {
    let scale: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(DesignSystem.Animations.quickSpring, value: configuration.isPressed)
    }
}
