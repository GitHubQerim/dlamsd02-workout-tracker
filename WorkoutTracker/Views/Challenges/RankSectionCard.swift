import SwiftUI

/// "Dein Rang"-Sektion (ADR 0014): Rang-Badge + Name, Fortschritts-Ring
/// Richtung nächstem Rang, globaler Streak-Indikator, optionale "Willkommen
/// zurück"-Zeile nach nachgeholtem Inaktivitäts-Decay.
struct RankSectionCard: View {
    let elo: Int
    let tier: RankTier
    let streakDays: Int
    /// Ergebnis von `ChallengesViewModel.reconcileRankDecayOnAppear` - nur
    /// bei `daysDecayed > 0` wird die Willkommen-zurück-Zeile gezeigt.
    var welcomeBack: RankReconciliationResult?

    private var ringProgress: (value: Int, max: Int) {
        RankEngine.tierProgress(forElo: elo)
    }

    var body: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSSpacing.s8) {
                HStack(spacing: DSSpacing.cardGap) {
                    RankBadge(tier: tier, size: 40)
                    VStack(alignment: .leading, spacing: DSSpacing.s4) {
                        Text(tier.displayName)
                            .font(DSFont.body)
                            .foregroundStyle(DSColor.textPrimary)
                        HStack(spacing: 4) {
                            DSIcon(name: "flame", size: 13)
                                .foregroundStyle(DSColor.textSecondary)
                            Text("\(streakDays) Tage Streak")
                                .font(DSFont.caption)
                                .foregroundStyle(DSColor.textSecondary)
                        }
                    }
                    Spacer()
                    DSProgressRing(
                        value: ringProgress.value,
                        max: ringProgress.max,
                        size: 64,
                        thickness: 6,
                        label: "\(elo)",
                        labelFont: DSFont.body
                    )
                }

                if let welcomeBack, welcomeBack.daysDecayed > 0 {
                    Text("Willkommen zurück! \(welcomeBack.daysDecayed) Tag(e) pausiert, \(welcomeBack.decayElo) Elo verloren.")
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textSecondary)
                }
            }
        }
    }
}
