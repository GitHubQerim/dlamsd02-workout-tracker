import SwiftUI

/// Selectable pill adapted from `components/core/Chip.jsx` — used for the
/// category and difficulty pickers on the start screen.
struct DSChip: View {
    let title: String
    var icon: String? = nil
    var active: Bool = false
    var action: () -> Void

    private var background: Color { active ? DSColor.accentTrack : DSColor.n700 }
    private var foreground: Color { active ? DSColor.accent : DSColor.textPrimary }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon {
                    DSIcon(name: icon, size: 12)
                }
                Text(title)
                    .font(DSFont.caption)
            }
            .foregroundColor(foreground)
            .padding(.horizontal, DSSpacing.s12)
            .frame(minWidth: 56)
            .frame(minHeight: 26)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.chip, style: .continuous))
        }
        .buttonStyle(DSPressable())
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}
