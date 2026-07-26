import SwiftUI

/// Button adapted from `components/core/Button.jsx`. The source component
/// has more variants/sizes (light/ghost, sm/md) than this 3-screen quiz
/// app uses — trimmed to just the two variants and one size this app
/// actually renders, per YAGNI.
enum DSButtonVariant {
    case accent, outline

    var background: Color {
        self == .accent ? DSColor.accent : .clear
    }

    var foreground: Color {
        self == .accent ? DSColor.textOnInvert : DSColor.textPrimary
    }

    var border: Color? {
        self == .outline ? DSColor.borderStrong : nil
    }
}

struct DSButton: View {
    private static let height: CGFloat = 52
    private static let horizontalPadding: CGFloat = 20

    let title: String
    var icon: String? = nil
    var variant: DSButtonVariant = .accent
    var fullWidth: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    DSIcon(name: icon, size: 18)
                }
                Text(title)
                    .font(DSFont.body)
            }
            .foregroundColor(variant.foreground)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(minHeight: Self.height)
            .padding(.horizontal, Self.horizontalPadding)
            .background(variant.background)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(variant.border ?? .clear, lineWidth: 1)
            )
        }
        .buttonStyle(DSPressable())
    }
}
