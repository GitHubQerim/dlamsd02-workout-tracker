import SwiftUI

/// Feier-Screen nach "Speichern & beenden" - gestaffelte Reveal-Sequenz
/// (Dauer → Elo-Gewinn → Streak → ggf. Personal Records → ggf. Rang-
/// Aufstieg), Duolingo-Lektion-abgeschlossen-artig statt einer reinen
/// Zahlen-Auflistung, damit der "Gulf of Evaluation" (Nutzer sieht Zahlen,
/// muss sie selbst interpretieren) geschlossen wird. Ersetzt die frühere
/// `WorkoutFeedbackView` (Notiz-Eingabe entfernt - `session.notes` wurde
/// nirgendwo im Code je wieder angezeigt, eine reine Sackgasse).
///
/// Kein Widerspruch zu ADR 0003 ("kein eigener Timer/Task für die laufende
/// Session-Uhr"): die Reveal-Sequenz hier ist eine ENDLICHE, feste Abfolge
/// weniger `Task.sleep`-Pausen (wie bereits in `ConfettiView.burst()`),
/// kein wiederkehrender/offener Zähler.
struct WorkoutCompletionView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: WorkoutSessionViewModel

    /// Eine einzelne, monoton fortschreitende Stufe statt sechs einzelner
    /// Bools - verhindert, dass Reveal-Zustände unabhängig voneinander
    /// (und damit potenziell in falscher Reihenfolge) gesetzt werden.
    private enum Stage: Int, Comparable {
        case notStarted, headline, elo, streak, records, rankUp, done
        static func < (lhs: Stage, rhs: Stage) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    @State private var stage: Stage = .notStarted
    @State private var animatedEloDelta = 0
    /// Bool-Trigger statt direkt auf Zustand zu feuern: `.sensoryFeedback`
    /// löst nur bei einer ÄNDERUNG aus, die Reveal-Sequenz kippt diese Bools
    /// explizit an der jeweils passenden Stelle von `false` auf `true`.
    @State private var eloGainTrigger = false
    @State private var rankUpTrigger = false
    @State private var confettiTrigger = false

    private static let stageDelay: Duration = .seconds(0.35)
    private static let countUpKickoffDelay: Duration = .seconds(0.1)
    /// Konfetti nur bei Meilensteinen (Rang-Aufstieg oder Streak-Meilenstein),
    /// nicht bei jedem normalen Elo-Gewinn - sonst wirkt es repetitiv (ADR 0014).
    private static let streakMilestones: Set<Int> = [7, 30, 100]

    private var duration: TimeInterval {
        guard let endDate = viewModel.session.endDate else { return 0 }
        return endDate.timeIntervalSince(viewModel.session.startDate)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DSWashedScreen {
                    VStack(alignment: .leading, spacing: DSSpacing.sectionGap) {
                        if stage >= .headline {
                            headline
                                .transition(.scale.combined(with: .opacity))
                        }

                        if stage >= .elo, let result = viewModel.lastRankReconciliation {
                            DSCard {
                                HStack(spacing: DSSpacing.cardGap) {
                                    DSStatTile(label: "Elo", icon: "chart-column", value: eloDeltaLabel(animatedEloDelta), valueColor: DSColor.accent)
                                        .contentTransition(.numericText())
                                    if stage >= .streak {
                                        DSStatTile(label: "Streak", icon: "flame", value: "\(result.streakDays) Tage")
                                            .transition(.scale.combined(with: .opacity))
                                    }
                                }
                            }
                            .transition(.scale.combined(with: .opacity))
                        }

                        if stage >= .records {
                            recordsCard
                                .transition(.scale.combined(with: .opacity))
                        }

                        if stage >= .rankUp, let result = viewModel.lastRankReconciliation, result.newTier > result.oldTier {
                            rankUpCard(for: result)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
                ConfettiView(trigger: $confettiTrigger)
            }
            .safeAreaInset(edge: .bottom) {
                if stage >= .done {
                    DSButton(title: "Fertig", fullWidth: true) { dismiss() }
                        .padding(.horizontal, DSSpacing.screenGutter)
                        .padding(.bottom, DSSpacing.s8)
                        .transition(.opacity)
                }
            }
            .sensoryFeedback(.increase, trigger: eloGainTrigger)
            .sensoryFeedback(.levelChange, trigger: rankUpTrigger)
            .task { await runCelebrationSequence() }
        }
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: DSSpacing.s4) {
            Text("Workout abgeschlossen!")
                .font(DSFont.screenTitle)
                .foregroundStyle(DSColor.textPrimary)
            Text("\(viewModel.displayTitle) · \(duration.formattedClock)")
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
        }
    }

    @ViewBuilder
    private var recordsCard: some View {
        let records = viewModel.session.personalRecords
        if !records.isEmpty {
            DSCard {
                VStack(alignment: .leading, spacing: DSSpacing.s8) {
                    Text("Neue Bestleistung")
                        .font(DSFont.label)
                        .foregroundStyle(DSColor.textSecondary)
                    ForEach(records) { record in
                        PersonalRecordRow(record: record)
                    }
                }
            }
        }
    }

    private func rankUpCard(for result: RankReconciliationResult) -> some View {
        DSCard {
            VStack(spacing: DSSpacing.s4) {
                RankBadge(tier: result.newTier, size: 72)
                Text("Neuer Rang: \(result.newTier.displayName)!")
                    .font(DSFont.label)
                    .foregroundStyle(DSColor.textPrimary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// "+X" nur bei tatsächlichem Gewinn - `eloDelta` kann negativ sein
    /// (Inaktivitäts-Decay übersteigt den Gewinn dieser Session), ein
    /// hartkodiertes "+" davor würde dann "+-30" statt "-30" anzeigen.
    private func eloDeltaLabel(_ eloDelta: Int) -> String {
        eloDelta > 0 ? "+\(eloDelta)" : "\(eloDelta)"
    }

    /// Pausiert bis zur nächsten Stufe und meldet zurück, ob die Sequenz
    /// weiterlaufen soll. `Task.sleep` wirft bei Abbruch (View weggewischt,
    /// Sheet geschlossen) `CancellationError` - ein bloßes `try?` würde das
    /// verschlucken und die Sequenz sofort und ungebremst bis zum Ende
    /// durchlaufen lassen (inkl. Haptik/Konfetti auf einer bereits
    /// geschlossenen View). Deshalb explizit `Task.isCancelled` prüfen und
    /// an jeder Stufe abbrechen können.
    private func pause(_ duration: Duration = Self.stageDelay) async -> Bool {
        try? await Task.sleep(for: duration)
        return !Task.isCancelled
    }

    private func runCelebrationSequence() async {
        guard let result = viewModel.lastRankReconciliation else {
            withAnimation(DSMotion.expand) { stage = .headline }
            withAnimation(DSMotion.base) { stage = .done }
            return
        }

        withAnimation(DSMotion.expand) { stage = .headline }
        guard await pause() else { return }

        // Die Elo-Kachel erscheint zuerst bei "0", der eigentliche Zähl-
        // Effekt (`.contentTransition(.numericText())`) passiert erst im
        // zweiten Schritt, wenn sie schon sichtbar ist - andernfalls gäbe
        // es keinen vorherigen Anzeigewert, von dem aus animiert werden
        // könnte, und die Zahl würde nur direkt im Endwert erscheinen.
        withAnimation(DSMotion.expand) { stage = .elo }
        guard await pause(Self.countUpKickoffDelay) else { return }
        withAnimation(.easeOut(duration: 0.5)) { animatedEloDelta = result.eloDelta }
        if result.eloDelta > 0 {
            eloGainTrigger = true
        }
        guard await pause() else { return }

        withAnimation(DSMotion.expand) { stage = .streak }
        let rankedUp = result.newTier > result.oldTier
        // Streak-Meilenstein-Konfetti nur wenn KEIN Rang-Aufstieg diese
        // Session passiert - der Aufstieg ist der größere Moment und
        // bekommt sein eigenes Konfetti weiter unten, kein Doppel-Burst.
        if !rankedUp && result.awardedDailyBonus && Self.streakMilestones.contains(result.streakDays) {
            confettiTrigger = true
        }
        guard await pause() else { return }

        withAnimation(DSMotion.expand) { stage = .records }
        // Ohne neue Bestleistung zeigt diese Stufe nichts an - keine Pause
        // dafür verschwenden, sonst wartet der Nutzer sichtbar auf nichts.
        if !viewModel.session.personalRecords.isEmpty {
            guard await pause() else { return }
        }

        if rankedUp {
            withAnimation(DSMotion.expand) { stage = .rankUp }
            rankUpTrigger = true
            confettiTrigger = true
            guard await pause() else { return }
        }

        withAnimation(DSMotion.base) { stage = .done }
    }
}
