import SwiftUI

/// Kurzer Zwischenscreen nach "Speichern & beenden": eine optionale Notiz
/// zur gerade abgeschlossenen Session, plus Streak-/Elo-/Rang-Feier (ADR
/// 0014). Nicht verpflichtend - Wegwischen ohne "Fertig" lässt die Notiz
/// einfach leer/unverändert (siehe onDismiss-Handling in `WorkoutSessionView`).
struct WorkoutFeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: WorkoutSessionViewModel

    @State private var notesDraft: String = ""
    /// Bool-Trigger statt direkt auf `lastRankReconciliation` zu feuern:
    /// `.sensoryFeedback(trigger:)` löst nur bei einer ÄNDERUNG des Trigger-
    /// Werts aus, der Reconciliation-Wert liegt aber schon beim ersten
    /// Erscheinen der View fest - `onAppear` kippt diese Bools explizit von
    /// `false` auf `true`, damit die Haptik wirklich feuert.
    @State private var eloGainTrigger = false
    @State private var rankUpTrigger = false
    @State private var confettiTrigger = false

    /// Konfetti nur bei Meilensteinen (Rang-Aufstieg oder Streak-Meilenstein),
    /// nicht bei jedem normalen Elo-Gewinn - sonst wirkt es repetitiv (ADR 0014).
    private static let streakMilestones: Set<Int> = [7, 30, 100]

    var body: some View {
        NavigationStack {
            ZStack {
                DSWashedScreen {
                    VStack(alignment: .leading, spacing: DSSpacing.sectionGap) {
                        Text("Training abgeschlossen")
                            .font(DSFont.screenTitle)
                            .foregroundStyle(DSColor.textPrimary)

                        if let result = viewModel.lastRankReconciliation {
                            rankSummary(for: result)
                        }

                        DSCard {
                            VStack(alignment: .leading, spacing: DSSpacing.s8) {
                                Text("Notiz")
                                    .font(DSFont.label)
                                    .foregroundStyle(DSColor.textSecondary)
                                TextField("Wie lief's? (optional)", text: $notesDraft, axis: .vertical)
                                    .font(DSFont.body)
                                    .foregroundStyle(DSColor.textPrimary)
                                    .lineLimit(4...8)
                            }
                        }

                        DSButton(title: "Fertig", fullWidth: true) {
                            viewModel.updateNotes(notesDraft)
                            dismiss()
                        }
                    }
                }
                ConfettiView(trigger: $confettiTrigger)
            }
            .sensoryFeedback(.increase, trigger: eloGainTrigger)
            .sensoryFeedback(.levelChange, trigger: rankUpTrigger)
            .onAppear {
                notesDraft = viewModel.session.notes ?? ""
                triggerCelebration()
            }
        }
    }

    @ViewBuilder
    private func rankSummary(for result: RankReconciliationResult) -> some View {
        let rankedUp = result.newTier > result.oldTier
        DSCard {
            VStack(spacing: DSSpacing.s8) {
                HStack(spacing: DSSpacing.cardGap) {
                    DSStatTile(label: "Elo", icon: "chart-column", value: eloDeltaLabel(result.eloDelta), valueColor: DSColor.accent)
                    DSStatTile(label: "Streak", icon: "flame", value: "\(result.streakDays) Tage")
                }
                if rankedUp {
                    VStack(spacing: DSSpacing.s4) {
                        RankBadge(tier: result.newTier, size: 72)
                        Text("Neuer Rang: \(result.newTier.displayName)!")
                            .font(DSFont.label)
                            .foregroundStyle(DSColor.textPrimary)
                    }
                }
            }
        }
    }

    /// "+X" nur bei tatsächlichem Gewinn - `result.eloDelta` kann negativ
    /// sein (Inaktivitäts-Decay übersteigt den Gewinn dieser Session), ein
    /// hartkodiertes "+" davor würde dann "+-30" statt "-30" anzeigen.
    private func eloDeltaLabel(_ eloDelta: Int) -> String {
        eloDelta > 0 ? "+\(eloDelta)" : "\(eloDelta)"
    }

    private func triggerCelebration() {
        guard let result = viewModel.lastRankReconciliation else { return }
        if result.eloDelta > 0 {
            eloGainTrigger = true
        }
        let rankedUp = result.newTier > result.oldTier
        if rankedUp {
            rankUpTrigger = true
        }
        // Streak-Meilenstein-Konfetti nur an der Session, die den Tages-
        // Bonus tatsächlich vergeben hat - sonst würde eine zweite Session
        // am selben Streak-Meilenstein-Tag (streakDays ändert sich erst am
        // nächsten Kalendertag) die Feier ein zweites Mal auslösen.
        if rankedUp || (result.awardedDailyBonus && Self.streakMilestones.contains(result.streakDays)) {
            confettiTrigger = true
        }
    }
}
