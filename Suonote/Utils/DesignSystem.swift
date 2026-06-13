import SwiftUI

// MARK: - Design System
/// Adaptive light/dark palette with Suonote teal as the brand accent.
/// Liquid Glass (iOS 26) is used for the navigation/control layer;
/// content surfaces stay solid for legibility.

struct DesignSystem {

    // MARK: - Colors

    struct Colors {
        // Primary Palette
        static let primary = Color(light: "00CCBE", dark: "1ADBCE")        // Suonote teal
        static let primaryLight = Color(light: "8FE9E3", dark: "2E5F5B")
        static let primaryDark = Color(light: "00AFA3", dark: "00C2B5")
        static let accent = Color(light: "E3A894", dark: "EDB9A6")         // Warm peach

        // Backgrounds
        static let background = Color(light: "FBFAFD", dark: "0C0D12")
        static let backgroundSecondary = Color(light: "FFFFFF", dark: "14151C")
        static let backgroundTertiary = Color(light: "F3F5FA", dark: "1A1C24")

        // Surface Colors
        static let surface = Color(light: "FFFFFF", dark: "171922")
        static let surfaceSecondary = Color(light: "F6F7FB", dark: "1D2029")
        static let surfaceHover = Color(light: "EEF1F8", dark: "232733")
        static let surfaceActive = Color(light: "E6EBF6", dark: "2A2F3D")

        // Text Colors
        static let textPrimary = Color(light: "2F2E35", dark: "ECECF2")
        static let textSecondary = Color(light: "6E7480", dark: "A4A9B6")
        static let textTertiary = Color(light: "9EA5B1", dark: "6F7582")
        static let textWhite = Color(light: "FEFEFE", dark: "FEFEFE")
        static let textMuted = Color(light: "B7B0D8", dark: "8E86BC")

        // Border Colors
        static let border = Color(light: "E3E6F0", dark: "2A2D3A")
        static let borderActive = Color(light: "CBD7F2", dark: "3E4558")
        static let borderSubtle = Color(light: "F1F3F8", dark: "222530")

        // Status Colors
        static let success = Color(light: "7FC6A8", dark: "8FD6B8")
        static let warning = Color(light: "E1B56E", dark: "EDC684")
        static let error = Color(light: "D99292", dark: "E8A3A3")
        static let info = Color(light: "7AA9DE", dark: "8FBCEE")
        static let secondary = Color(light: "8F97A9", dark: "9BA3B5")

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

    struct Typography {
        // Display (Erode)
        static let display = Font.erode(42, relativeTo: .largeTitle).weight(.semibold)
        static let displayLarge = Font.erode(50, relativeTo: .largeTitle).weight(.semibold)

        // Headings (Erode)
        static let largeTitle = Font.erode(36, relativeTo: .largeTitle).weight(.semibold)
        static let title = Font.erode(30, relativeTo: .title).weight(.semibold)
        static let title2 = Font.erode(24, relativeTo: .title2).weight(.semibold)
        static let title3 = Font.erode(22, relativeTo: .title3).weight(.semibold)

        // Headlines (Erode for emphasis)
        static let headline = Font.erode(18, relativeTo: .headline).weight(.semibold)
        static let subheadline = Font.erode(16, relativeTo: .subheadline).weight(.semibold)

        // Body (Mix of Erode and Manrope)
        static let body = Font.manrope(15, relativeTo: .body)
        static let bodyBold = Font.erode(15, relativeTo: .body).weight(.semibold)
        static let bodyMedium = Font.erode(15, relativeTo: .body).weight(.semibold)
        static let callout = Font.manrope(13, relativeTo: .callout)
        static let calloutBold = Font.erode(13, relativeTo: .callout).weight(.semibold)

        // Captions (Manrope)
        static let caption = Font.manrope(12, relativeTo: .caption)
        static let caption2 = Font.manrope(11, relativeTo: .caption2)
        static let footnote = Font.manrope(13, relativeTo: .footnote)

        // Extra Large (Erode)
        static let hero = Font.erode(120, relativeTo: .largeTitle).weight(.bold)
        static let mega = Font.erode(72, relativeTo: .largeTitle).weight(.bold)
        static let jumbo = Font.erode(60, relativeTo: .largeTitle).weight(.semibold)
        static let giant = Font.erode(56, relativeTo: .largeTitle).weight(.semibold)
        static let huge = Font.erode(48, relativeTo: .largeTitle).weight(.semibold)
        static let xxl = Font.erode(44, relativeTo: .largeTitle).weight(.medium)
        static let xl = Font.erode(40, relativeTo: .largeTitle).weight(.medium)
        static let lg = Font.erode(36, relativeTo: .title).weight(.medium)
        static let md = Font.erode(32, relativeTo: .title).weight(.medium)
        static let sm = Font.erode(24, relativeTo: .title2).weight(.medium)

        // Micro (Manrope)
        static let micro = Font.manrope(10, relativeTo: .caption2)
        static let nano = Font.manrope(8, relativeTo: .caption2)

        // Special
        static let monospaced = Font.system(.body, design: .monospaced)
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
    }

    // MARK: - Animations

    struct Animations {
        static let quickSpring = Animation.spring(response: 0.3, dampingFraction: 0.7)
        static let smoothSpring = Animation.spring(response: 0.4, dampingFraction: 0.8)
        static let gentleSpring = Animation.spring(response: 0.5, dampingFraction: 0.9)

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

// MARK: - Reusable Components

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
            HStack(spacing: DesignSystem.Spacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .font(DesignSystem.Typography.headline)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.xxs)
        }
        .buttonStyle(.glassProminent)
        .tint(isDestructive ? DesignSystem.Colors.error : DesignSystem.Colors.primary)
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
                if let icon = icon {
                    Image(systemName: icon)
                        .font(DesignSystem.Typography.caption)
                }
                Text(title)
                    .font(DesignSystem.Typography.callout)
            }
            .foregroundStyle(DesignSystem.Colors.textPrimary)
            .padding(.horizontal, DesignSystem.Spacing.xxs)
            .padding(.vertical, DesignSystem.Spacing.xxxs)
        }
        .buttonStyle(.glass)
    }
}

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
            .fontWeight(.medium)
            .foregroundStyle(DesignSystem.Colors.textPrimary)
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xxs)
            .background(
                Capsule()
                    .fill(color.opacity(0.2))
                    .overlay(
                        Capsule().stroke(color.opacity(0.4), lineWidth: 1)
                    )
            )
    }
}

// MARK: - Chip & Button Components

struct AppChip: View {
    let text: String
    var icon: String? = nil
    var tint: Color = DesignSystem.Colors.primary
    var textColor: Color = DesignSystem.Colors.textPrimary
    var fillOpacity: Double = 0.2
    var strokeOpacity: Double = 0.45
    var font: Font = DesignSystem.Typography.caption

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xxs) {
            if let icon {
                Image(systemName: icon)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(tint)
            }
            Text(text)
                .font(font)
                .foregroundStyle(textColor)
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xxs)
        .background(
            Capsule()
                .fill(tint.opacity(fillOpacity))
                .overlay(
                    Capsule()
                        .stroke(tint.opacity(strokeOpacity), lineWidth: 1)
                )
        )
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
                .buttonStyle(.glassProminent)
                .tint(color)
        case .secondary:
            baseButton
                .buttonStyle(.glass)
        case .destructive:
            baseButton
                .buttonStyle(.glassProminent)
                .tint(DesignSystem.Colors.error)
        }
    }

    private var baseButton: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.xxs) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .font(DesignSystem.Typography.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.xxs)
        }
    }
}

struct LoadingView: View {
    let message: String

    init(_ message: String = "Loading...") {
        self.message = message
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(DesignSystem.Colors.primary)

            Text(message)
                .font(DesignSystem.Typography.callout)
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
        VStack(spacing: DesignSystem.Spacing.xl) {
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.primary.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: icon)
                    .font(.system(size: 48))
                    .foregroundStyle(DesignSystem.Colors.primary)
            }

            VStack(spacing: DesignSystem.Spacing.xs) {
                Text(title)
                    .font(DesignSystem.Typography.title2)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Text(message)
                    .font(DesignSystem.Typography.callout)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle = actionTitle, let action = action {
                PrimaryButton(actionTitle, icon: DesignSystem.Icons.add, action: action)
                    .padding(.horizontal, DesignSystem.Spacing.xxl)
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
    /// Solid content surface. Content stays opaque for legibility;
    /// Liquid Glass is reserved for floating controls.
    func cardStyle(cornerRadius: CGFloat = DesignSystem.CornerRadius.xl, color: Color? = nil) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(DesignSystem.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(color ?? DesignSystem.Colors.border, lineWidth: 1)
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
