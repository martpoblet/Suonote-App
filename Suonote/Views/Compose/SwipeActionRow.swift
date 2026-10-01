import SwiftUI

// MARK: - Swipe Action Row
/// Row with revealable leading/trailing circular actions. Shared with Studio.
struct SwipeActionItem: Identifiable {
    let id = UUID()
    let systemImage: String
    let tint: Color
    let role: ButtonRole?
    /// VoiceOver label; derived from the role when omitted.
    var label: String? = nil
    let action: () -> Void

    var accessibilityText: String {
        if let label { return label }
        return role == .destructive ? String(localized: "Delete") : String(localized: "Action")
    }
}

struct SwipeActionRow<Content: View>: View {
    let actions: [SwipeActionItem]
    let leadingActions: [SwipeActionItem]
    let content: Content
    
    private let buttonSize: CGFloat = 40
    private let buttonSpacing: CGFloat = 12
    private let actionGap: CGFloat = 24
    @State private var baseOffset: CGFloat = 0
    @State private var dragTranslation: CGFloat = 0
    
    init(
        actions: [SwipeActionItem],
        leadingActions: [SwipeActionItem] = [],
        @ViewBuilder content: () -> Content
    ) {
        self.actions = actions
        self.leadingActions = leadingActions
        self.content = content()
    }
    
    private var actionsWidth: CGFloat {
        guard !actions.isEmpty else { return 0 }
        return (CGFloat(actions.count) * buttonSize) + (CGFloat(max(actions.count - 1, 0)) * buttonSpacing)
    }

    private var leadingActionsWidth: CGFloat {
        guard !leadingActions.isEmpty else { return 0 }
        return (CGFloat(leadingActions.count) * buttonSize) + (CGFloat(max(leadingActions.count - 1, 0)) * buttonSpacing)
    }
    
    private var maxOffset: CGFloat {
        guard !actions.isEmpty else { return 0 }
        return actionsWidth + actionGap
    }

    private var maxLeadingOffset: CGFloat {
        guard !leadingActions.isEmpty else { return 0 }
        return leadingActionsWidth + actionGap
    }
    
    private var dragOffset: CGFloat {
        clampOffset(baseOffset + dragTranslation)
    }
    
    private var revealWidth: CGFloat {
        max(0, -dragOffset)
    }

    private var leadingRevealWidth: CGFloat {
        max(0, dragOffset)
    }
    
    private var revealProgress: CGFloat {
        guard actionsWidth > 0 else { return 0 }
        return min(1, revealWidth / actionsWidth)
    }

    private var leadingRevealProgress: CGFloat {
        guard leadingActionsWidth > 0 else { return 0 }
        return min(1, leadingRevealWidth / leadingActionsWidth)
    }
    
    private var effectiveRevealWidth: CGFloat {
        min(revealWidth, actionsWidth)
    }

    private var effectiveLeadingRevealWidth: CGFloat {
        min(leadingRevealWidth, leadingActionsWidth)
    }
    
    var body: some View {
        ZStack {
            actionButtons
            leadingActionButtons
            
            content
                .offset(x: dragOffset)
                .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.85), value: baseOffset)
                .gesture(
                    HorizontalPanGesture(
                        onChanged: { translation in
                            dragTranslation = translation
                        },
                        onEnded: { translation in
                            let proposedOffset = clampOffset(baseOffset + translation)
                            if proposedOffset >= maxLeadingOffset * 0.5 {
                                baseOffset = maxLeadingOffset
                            } else if proposedOffset <= -maxOffset * 0.5 {
                                baseOffset = -maxOffset
                            } else {
                                baseOffset = 0
                            }
                            dragTranslation = 0
                        }
                    )
                )
        }
        .clipped()
    }
    
    private var actionButtons: some View {
        HStack(spacing: buttonSpacing) {
            ForEach(Array(actions.enumerated()), id: \.element.id) { index, item in
                let progress = buttonProgress(for: index)
                Button(role: item.role) {
                    item.action()
                    baseOffset = 0
                } label: {
                    Image(systemName: item.systemImage)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.textWhite)
                        .frame(width: buttonSize, height: buttonSize)
                        .background(Circle().fill(item.tint))
                }
                .accessibilityLabel(item.accessibilityText)
                .scaleEffect(progress, anchor: .trailing)
                .opacity(progress)
                .buttonStyle(.plain)
            }
        }
        .padding(.trailing, 12)
        .frame(width: actionsWidth, alignment: .trailing)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .opacity(revealProgress == 0 ? 0 : 1)
        .animation(.easeOut(duration: 0.18), value: revealProgress)
    }

    private var leadingActionButtons: some View {
        HStack(spacing: buttonSpacing) {
            ForEach(Array(leadingActions.enumerated()), id: \.element.id) { index, item in
                let progress = leadingButtonProgress(for: index)
                Button(role: item.role) {
                    item.action()
                    baseOffset = 0
                } label: {
                    Image(systemName: item.systemImage)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.textWhite)
                        .frame(width: buttonSize, height: buttonSize)
                        .background(Circle().fill(item.tint))
                }
                .accessibilityLabel(item.accessibilityText)
                .scaleEffect(progress, anchor: .leading)
                .opacity(progress)
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 12)
        .frame(width: leadingActionsWidth, alignment: .leading)
        .opacity(leadingRevealProgress == 0 ? 0 : 1)
        .animation(.easeOut(duration: 0.18), value: leadingRevealProgress)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func buttonProgress(for index: Int) -> CGFloat {
        let threshold = CGFloat(index) * (buttonSize + buttonSpacing)
        let raw = (effectiveRevealWidth - threshold) / buttonSize
        return max(0, min(1, raw))
    }

    private func leadingButtonProgress(for index: Int) -> CGFloat {
        let threshold = CGFloat(index) * (buttonSize + buttonSpacing)
        let raw = (effectiveLeadingRevealWidth - threshold) / buttonSize
        return max(0, min(1, raw))
    }
    
    private func clampOffset(_ offset: CGFloat) -> CGFloat {
        max(-maxOffset, min(maxLeadingOffset, offset))
    }
}

@MainActor
struct HorizontalPanGesture: UIGestureRecognizerRepresentable {
    typealias UIGestureRecognizerType = UIPanGestureRecognizer
    var onChanged: (CGFloat) -> Void
    var onEnded: (CGFloat) -> Void
    
    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let recognizer = UIPanGestureRecognizer()
        recognizer.maximumNumberOfTouches = 1
        return recognizer
    }
    
    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = context.coordinator
    }
    
    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let translation = recognizer.translation(in: recognizer.view).x
        switch recognizer.state {
        case .began, .changed:
            onChanged(translation)
        case .ended, .cancelled, .failed:
            onEnded(translation)
        default:
            break
        }
    }
    
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private let parent: HorizontalPanGesture
        
        init(_ parent: HorizontalPanGesture) {
            self.parent = parent
        }
        
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y) * 1.3
        }
        
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            false
        }
    }
}
