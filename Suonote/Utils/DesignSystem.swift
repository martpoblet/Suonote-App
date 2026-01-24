import SwiftUI

// MARK: - Design System
/// Deep Amethyst Edition - Light mode with purple/violet accents

struct DesignSystem {

    // MARK: - Colors

    struct Colors {
        // Primary Palette - Pastel Harmony
        static let primary = Color(hexNonOptional: "6F8FDD")        // Periwinkle with more contrast
        static let primaryLight = Color(hexNonOptional: "B8C7F0")   // Light lavender blue
        static let primaryDark = Color(hexNonOptional: "4E73C8")    // Muted periwinkle
        static let accent = Color(hexNonOptional: "E3A894")         // Warm peach

        // Backgrounds - Light mode
        static let background = Color(hexNonOptional: "FBFAFD")     // Soft warm white
        static let backgroundSecondary = Color(hexNonOptional: "FFFFFF") // Pure white
        static let backgroundTertiary = Color(hexNonOptional: "F3F5FA")  // Misty blue gray

        // Surface Colors
        static let surface = Color.white
        static let surfaceSecondary = Color(hexNonOptional: "F6F7FB") // Airy lavender
        static let surfaceHover = Color(hexNonOptional: "EEF1F8")
        static let surfaceActive = Color(hexNonOptional: "E6EBF6")

        // Text Colors
        static let textPrimary = Color(hexNonOptional: "2F2E35")    // Soft charcoal (unified ink)
        static let textSecondary = Color(hexNonOptional: "6E7480")  // Neutral gray
        static let textTertiary = Color(hexNonOptional: "9EA5B1")   // Light gray
        static let textMuted = Color(hexNonOptional: "B7B0D8")      // Muted lavender

        // Border Colors
        static let border = Color(hexNonOptional: "E3E6F0")         // Light pastel border
        static let borderActive = Color(hexNonOptional: "CBD7F2")   // Active pastel border
        static let borderSubtle = Color(hexNonOptional: "F1F3F8")   // Very subtle

        // Status Colors
        static let success = Color(hexNonOptional: "7FC6A8")
        static let warning = Color(hexNonOptional: "E1B56E")
        static let error = Color(hexNonOptional: "D99292")
        static let info = Color(hexNonOptional: "7AA9DE")
        static let secondary = Color(hexNonOptional: "8F97A9")  // Gray color for secondary elements

        // Tab Bar
        static let tabBarBackground = Color(hexNonOptional: "FBFAFD")
        static let tabBarActive = primaryDark
        static let tabBarInactive = textSecondary

        // Gradients
        static let primaryGradient = LinearGradient(
            colors: [primary, primaryLight],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let accentGradient = LinearGradient(
            colors: [accent, primaryLight],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let subtleGradient = LinearGradient(
            colors: [Color(hexNonOptional: "FAF9FB"), Color(hexNonOptional: "F5F3F7")],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Typography

    struct Typography {
        // Display (Piazzolla) - Increased weights for prominence
        static let display = Font.piazzolla(42).weight(.semibold)
        static let displayLarge = Font.piazzolla(50).weight(.semibold)

        // Headings (Piazzolla) - Enhanced weights
        static let largeTitle = Font.piazzolla(36).weight(.semibold)
        static let title = Font.piazzolla(30).weight(.semibold)
        static let title2 = Font.piazzolla(24).weight(.semibold)
        static let title3 = Font.piazzolla(22).weight(.medium)

        // Headlines (Piazzolla for emphasis) - Using Piazzolla more
        static let headline = Font.piazzolla(18).weight(.semibold)
        static let subheadline = Font.piazzolla(16).weight(.medium)

        // Body (Mix of Piazzolla and Manrope)
        static let body = Font.manrope(15)
        static let bodyBold = Font.piazzolla(15).weight(.semibold)
        static let bodyMedium = Font.piazzolla(15).weight(.medium)
        static let callout = Font.manrope(13)
        static let calloutBold = Font.piazzolla(13).weight(.semibold)

        // Captions (Manrope)
        static let caption = Font.manrope(12)
        static let caption2 = Font.manrope(11)
        static let footnote = Font.manrope(13)

        // Extra Large (Piazzolla) - Enhanced weights
        static let hero = Font.piazzolla(120).weight(.bold)
        static let mega = Font.piazzolla(72).weight(.bold)
        static let jumbo = Font.piazzolla(60).weight(.semibold)
        static let giant = Font.piazzolla(56).weight(.semibold)
        static let huge = Font.piazzolla(48).weight(.semibold)
        static let xxl = Font.piazzolla(44).weight(.medium)
        static let xl = Font.piazzolla(40).weight(.medium)
        static let lg = Font.piazzolla(36).weight(.medium)
        static let md = Font.piazzolla(32).weight(.medium)
        static let sm = Font.piazzolla(24).weight(.medium)

        // Micro (Manrope)
        static let micro = Font.manrope(10)
        static let nano = Font.manrope(8)

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

    // MARK: - Shadows

    struct Shadows {
        static let sm = Shadow(color: .clear, radius: 0, x: 0, y: 0)
        static let md = Shadow(color: .clear, radius: 0, x: 0, y: 0)
        static let lg = Shadow(color: .clear, radius: 0, x: 0, y: 0)
        static let card = Shadow(color: .clear, radius: 0, x: 0, y: 0)
    }

    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
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
        static let key = "key.fill"
        static let tempo = "metronome"
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

// MARK: - Color Extension for Hex

extension Color {
    init(hexNonOptional hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
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
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Reusable Components (Light Mode)

struct CardView<Content: View>: View {
    let content: Content
    let cornerRadius: CGFloat

    init(cornerRadius: CGFloat = DesignSystem.CornerRadius.xl,
         @ViewBuilder content: () -> Content) {
        self.content = content()
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(DesignSystem.Colors.surface)
                    .shadow(
                        color: DesignSystem.Shadows.card.color,
                        radius: DesignSystem.Shadows.card.radius,
                        x: DesignSystem.Shadows.card.x,
                        y: DesignSystem.Shadows.card.y
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(DesignSystem.Colors.border, lineWidth: 1)
            )
    }
}

struct GlassCard<Content: View>: View {
    let content: Content
    let cornerRadius: CGFloat

    init(cornerRadius: CGFloat = DesignSystem.CornerRadius.xl,
         @ViewBuilder content: () -> Content) {
        self.content = content()
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(DesignSystem.Colors.surface)
                    .shadow(
                        color: DesignSystem.Shadows.sm.color,
                        radius: DesignSystem.Shadows.sm.radius
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(DesignSystem.Colors.border, lineWidth: 1)
            )
    }
}

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
            .foregroundStyle(DesignSystem.Colors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.md)
            .background(
                Capsule()
                    .fill(isDestructive ? DesignSystem.Colors.error : DesignSystem.Colors.primary)
            )
        }
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
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                Capsule()
                    .fill(DesignSystem.Colors.surface)
                    .overlay(
                        Capsule().stroke(DesignSystem.Colors.border, lineWidth: 1)
                    )
            )
        }
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

    private var tint: Color {
        switch kind {
        case .primary(let color):
            return color
        case .secondary:
            return DesignSystem.Colors.textPrimary
        case .destructive:
            return DesignSystem.Colors.error
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.xxs) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .font(DesignSystem.Typography.headline)
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.md)
            .background(
                Capsule()
                    .fill(backgroundFill)
                    .overlay(
                        Capsule()
                            .stroke(borderStroke, lineWidth: 1)
                    )
            )
        }
    }

    private var backgroundFill: Color {
        switch kind {
        case .primary(let color):
            return color.opacity(0.75)
        case .secondary:
            return DesignSystem.Colors.surfaceSecondary
        case .destructive:
            return DesignSystem.Colors.error.opacity(0.2)
        }
    }

    private var foregroundColor: Color {
        switch kind {
        case .primary:
            return DesignSystem.Colors.backgroundSecondary
        case .secondary, .destructive:
            return DesignSystem.Colors.textPrimary
        }
    }

    private var borderStroke: Color {
        switch kind {
        case .primary(let color):
            return color.opacity(0.6)
        case .secondary:
            return DesignSystem.Colors.border
        case .destructive:
            return DesignSystem.Colors.error.opacity(0.6)
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

    func glassStyle(cornerRadius: CGFloat = DesignSystem.CornerRadius.xl) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(DesignSystem.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(DesignSystem.Colors.border, lineWidth: 1)
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
