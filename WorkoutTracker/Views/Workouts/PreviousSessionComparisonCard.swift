import SwiftUI

/// Kompakter "Letztes Mal"-Vergleich für die aktive Übungskarte - macht
/// progressive Overload sichtbar, ohne die volle Tabelle der letzten
/// Session zu wiederholen (bewusst kompakter als eine 1:1-Kopie).
struct PreviousSessionComparisonCard: View {
    let attempt: PreviousAttempt

    private var setsText: String {
        attempt.sets
            .map { "\($0.reps) × \($0.weightKg.formatted(.number.precision(.fractionLength(0...1)))) kg" }
            .joined(separator: "  ·  ")
    }

    var body: some View {
        DSCard(padding: DSSpacing.s12, background: DSColor.surfaceInset) {
            VStack(alignment: .leading, spacing: DSSpacing.s4) {
                HStack(spacing: DSSpacing.s8) {
                    Text("Letztes Mal")
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textTertiary)
                    if let planName = attempt.planName {
                        Text("· \(planName)")
                            .font(DSFont.caption)
                            .foregroundStyle(DSColor.textTertiary)
                    }
                    Spacer(minLength: 0)
                    Text(attempt.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textTertiary)
                }
                Text(setsText)
                    .font(DSFont.label)
                    .foregroundStyle(DSColor.textSecondary)
            }
        }
        // Anders als bei SetRow (siehe dortiger Kommentar zur früheren
        // Regression) ist .combine hier unproblematisch: diese Karte enthält
        // ausschließlich Anzeigetext, keine interaktiven Controls. Combine
        // verhindert hier sogar, dass VoiceOver-Nutzer:innen durch mehrere
        // kleine Text-Fragmente einzeln swipen müssen.
        .accessibilityElement(children: .combine)
    }
}
