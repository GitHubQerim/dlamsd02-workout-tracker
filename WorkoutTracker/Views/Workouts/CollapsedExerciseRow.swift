import SwiftUI

/// Eingeklappte Zeile für eine nicht-aktive Übung im Akkordeon der
/// Session-Ansicht. Tippen klappt sie auf (siehe `WorkoutSessionView`).
struct CollapsedExerciseRow: View {
    let name: String
    let isComplete: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DSSpacing.stackGap) {
                Text(name)
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.textPrimary)
                Spacer()
                if isComplete {
                    DSIcon(name: "check", size: 16)
                        .foregroundStyle(DSColor.accent)
                }
            }
            .padding(.horizontal, DSSpacing.s16)
            .frame(minHeight: DSSpacing.tapMin)
            .background(DSColor.surfaceCard2)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
        }
        .buttonStyle(DSPressable())
        .accessibilityLabel(name)
        .accessibilityValue(isComplete ? "vollständig abgehakt" : "")
        .accessibilityHint("Doppeltippen zum Aufklappen")
    }
}
