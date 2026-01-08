import SwiftUI
import UIKit

// MARK: - Haptic Feedback Manager

enum HapticFeedback {
    case light
    case medium
    case heavy
    case soft
    case rigid
    case success
    case warning
    case error
    case selection
    
    func trigger() {
        switch self {
        case .light:
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            
        case .medium:
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
        case .heavy:
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
            
        case .soft:
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.impactOccurred()
            
        case .rigid:
            let generator = UIImpactFeedbackGenerator(style: .rigid)
            generator.impactOccurred()
            
        case .success:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
        case .warning:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
            
        case .error:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            
        case .selection:
            let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()
        }
    }
}

// MARK: - View Modifier for Haptic Feedback

struct HapticFeedbackModifier: ViewModifier {
    let feedback: HapticFeedback
    let trigger: Bool
    
    func body(content: Content) -> some View {
        content
            .onChange(of: trigger) { _, newValue in
                if newValue {
                    feedback.trigger()
                }
            }
    }
}

extension View {
    /// Adds haptic feedback when the trigger value changes
    func hapticFeedback(_ feedback: HapticFeedback, trigger: Bool) -> some View {
        modifier(HapticFeedbackModifier(feedback: feedback, trigger: trigger))
    }
    
    /// Adds haptic feedback on tap gesture
    func onTapWithHaptic(_ feedback: HapticFeedback = .light, perform action: @escaping () -> Void) -> some View {
        self.onTapGesture {
            feedback.trigger()
            action()
        }
    }
}

// MARK: - Button Style with Haptic

struct HapticButtonStyle: ButtonStyle {
    let feedback: HapticFeedback
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    feedback.trigger()
                }
            }
            .animation(DesignSystem.Animations.quickSpring, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == HapticButtonStyle {
    static func haptic(_ feedback: HapticFeedback = .light) -> HapticButtonStyle {
        HapticButtonStyle(feedback: feedback)
    }
}

// MARK: - Convenience Functions

/// Trigger haptic feedback easily from anywhere
func haptic(_ feedback: HapticFeedback) {
    feedback.trigger()
}

// MARK: - Preview
#Preview {
    VStack(spacing: DesignSystem.Spacing.lg) {
        Button("Light Haptic") {
            haptic(.light)
        }
        .buttonStyle(.haptic(.light))
        
        Button("Success Haptic") {
            haptic(.success)
        }
        .buttonStyle(.haptic(.success))
        
        Button("Error Haptic") {
            haptic(.error)
        }
        .buttonStyle(.haptic(.error))
    }
    .padding()
}
