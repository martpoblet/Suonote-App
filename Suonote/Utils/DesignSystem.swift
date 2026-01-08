import SwiftUI

// MARK: - Design System
/// Centralized design tokens for consistent UI/UX

struct DesignSystem {
    
    // MARK: - Colors
    
    struct Colors {
        // Primary Palette
        static let primary = Color.purple
        static let secondary = Color.blue
        static let accent = Color.cyan
        
        // Backgrounds
        static let background = Color.black
        static let backgroundSecondary = Color(red: 0.05, green: 0.05, blue: 0.15)
        static let backgroundTertiary = Color(red: 0.1, green: 0.05, blue: 0.2)
        
        // Surface Colors
        static let surface = Color.white.opacity(0.05)
        static let surfaceHover = Color.white.opacity(0.08)
        static let surfaceActive = Color.white.opacity(0.12)
        
        // Border Colors
        static let border = Color.white.opacity(0.1)
        static let borderActive = Color.white.opacity(0.3)
        
        // Status Colors
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        static let info = Color.blue
        
        // Gradients
        static let primaryGradient = LinearGradient(
            colors: [.purple, .blue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let accentGradient = LinearGradient(
            colors: [.cyan, .blue],
            startPoint: .leading,
            endPoint: .trailing
        )
        
        static let successGradient = LinearGradient(
            colors: [.green, .cyan],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Typography
    
    struct Typography {
        // Headings
        static let largeTitle = Font.system(size: 34, weight: .bold)
        static let title = Font.system(size: 28, weight: .bold)
        static let title2 = Font.system(size: 22, weight: .bold)
        static let title3 = Font.system(size: 20, weight: .semibold)
        
        // Body
        static let body = Font.system(size: 17, weight: .regular)
        static let bodyBold = Font.system(size: 17, weight: .semibold)
        static let callout = Font.system(size: 16, weight: .regular)
        
        // Captions
        static let caption = Font.system(size: 12, weight: .regular)
        static let caption2 = Font.system(size: 11, weight: .regular)
        static let footnote = Font.system(size: 13, weight: .regular)
        
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
        static let round: CGFloat = 999
    }
    
    // MARK: - Shadows
    
    struct Shadows {
        static let sm = Shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        static let md = Shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        static let lg = Shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)
        static let glow = Shadow(color: .purple.opacity(0.3), radius: 12, x: 0, y: 0)
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
        // Music
        static let chord = "music.note"
        static let chords = "music.note.list"
        static let key = "key.fill"
        static let tempo = "metronome"
        static let waveform = "waveform"
        
        // Actions
        static let add = "plus.circle.fill"
        static let delete = "trash.fill"
        static let edit = "pencil.circle.fill"
        static let duplicate = "doc.on.doc.fill"
        static let export = "square.and.arrow.up"
        
        // Media
        static let play = "play.fill"
        static let pause = "pause.fill"
        static let stop = "stop.fill"
        static let record = "record.circle.fill"
        
        // Navigation
        static let chevronUp = "chevron.up"
        static let chevronDown = "chevron.down"
        static let chevronLeft = "chevron.left"
        static let chevronRight = "chevron.right"
    }
}

// MARK: - Reusable Components

struct CardView<Content: View>: View {
    let content: Content
    let color: Color
    let cornerRadius: CGFloat
    
    init(color: Color = DesignSystem.Colors.primary,
         cornerRadius: CGFloat = DesignSystem.CornerRadius.lg,
         @ViewBuilder content: () -> Content) {
        self.content = content()
        self.color = color
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(color.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
            )
    }
}

struct GlassCard<Content: View>: View {
    let content: Content
    let cornerRadius: CGFloat
    
    init(cornerRadius: CGFloat = DesignSystem.CornerRadius.lg,
         @ViewBuilder content: () -> Content) {
        self.content = content()
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(DesignSystem.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(DesignSystem.Colors.border, lineWidth: 1)
                    )
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
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .font(DesignSystem.Typography.bodyBold)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.md)
            .background(
                Capsule()
                    .fill(isDestructive ? 
                          AnyShapeStyle(DesignSystem.Colors.error) : 
                          AnyShapeStyle(DesignSystem.Colors.primaryGradient))
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
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(DesignSystem.Typography.callout.weight(.semibold))
            }
            .foregroundStyle(.white)
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
            .font(DesignSystem.Typography.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xxs)
            .background(
                Capsule()
                    .fill(color.opacity(0.3))
                    .overlay(
                        Capsule().stroke(color, lineWidth: 1)
                    )
            )
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
                .foregroundStyle(.secondary)
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
                    .fill(DesignSystem.Colors.primaryGradient.opacity(0.2))
                    .frame(width: 120, height: 120)
                
                Image(systemName: icon)
                    .font(.system(size: 50))
                    .foregroundStyle(DesignSystem.Colors.primaryGradient)
            }
            
            VStack(spacing: DesignSystem.Spacing.xs) {
                Text(title)
                    .font(DesignSystem.Typography.title2)
                    .foregroundStyle(.white)
                
                Text(message)
                    .font(DesignSystem.Typography.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let actionTitle = actionTitle, let action = action {
                PrimaryButton(actionTitle, icon: DesignSystem.Icons.add, action: action)
                    .padding(.horizontal, DesignSystem.Spacing.xxl)
            }
        }
        .padding(DesignSystem.Spacing.xxl)
    }
}

// MARK: - View Extensions

extension View {
    func cardStyle(color: Color = DesignSystem.Colors.primary, cornerRadius: CGFloat = DesignSystem.CornerRadius.lg) -> some View {
        self.background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    func glassStyle(cornerRadius: CGFloat = DesignSystem.CornerRadius.lg) -> some View {
        self.background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(DesignSystem.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(DesignSystem.Colors.border, lineWidth: 1)
                )
        )
    }
    
    func animatedPress(scale: CGFloat = 0.95) -> some View {
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
