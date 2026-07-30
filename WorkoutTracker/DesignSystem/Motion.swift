import SwiftUI

/// Motion tokens adapted from tokens/motion.css.
enum DSMotion {
    static let fast = Animation.easeOut(duration: 0.16)
    static let base = Animation.easeOut(duration: 0.24)
    static let expand = Animation.spring(response: 0.35, dampingFraction: 0.75)

    /// Press-down scale for buttons/chips/cards, matching the source
    /// system's `scale(0.96)` + 70% opacity press feedback.
    static let pressScale: CGFloat = 0.96
    static let pressOpacity: Double = 0.7

    /// Opacity for a disabled tappable component - without this, `.disabled()`
    /// blocks the tap but looks visually identical to an enabled control (see
    /// docs/journal.md: root cause of the "button does nothing" reports).
    static let disabledOpacity: Double = 0.4
}

/// Shared press-feedback interaction (scale + opacity) for tappable
/// design-system components, so `DSButton`/`DSChip` don't each reimplement it.
struct DSPressable: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? DSMotion.pressScale : 1)
            .opacity(configuration.isPressed ? DSMotion.pressOpacity : (isEnabled ? 1 : DSMotion.disabledOpacity))
            .animation(DSMotion.fast, value: configuration.isPressed)
    }
}
