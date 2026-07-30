import Foundation

/// Alle Stellschrauben der Elo-Formel an einem Ort statt als Magic Numbers
/// verstreut - Feintuning ändert nur diese Datei, nie die Reconciliation-
/// Logik selbst. Werte sind bewusste, aber änderbare Startannahmen (siehe
/// ADR 0014).
enum RankTuning {
    /// Aufsteigend nach `RankTier`-Reihenfolge - Mindest-Elo je Rang.
    static let tierThresholds: [(tier: RankTier, minElo: Int)] = [
        (.bronze, 0),
        (.silver, 500),
        (.gold, 1000),
        (.platin, 1600),
        (.diamond, 2200),
        (.master, 2800),
        (.challenger, 3400)
    ]

    static let baseDailyBonus = 15

    /// Überlastungs-Bonus: +`overloadStepElo` je begonnener
    /// `overloadStepPercent`-Steigerung (relativ, nicht absolut - siehe
    /// ADR 0014), gedeckelt pro Übung und pro Session.
    static let overloadStepPercent: Double = 5
    static let overloadStepElo = 2
    static let overloadPerExerciseCap = 20
    static let overloadSessionCap = 40

    static let streakBoostPerDay = 1
    static let streakBoostCap = 20

    static let comebackStreakThreshold = 7
    static let comebackMultiplier = 2

    static let inactivityDecayPerDay = 5
}

/// Ergebnis eines einzelnen `RankEngine.reconcile`-Aufrufs - trägt alles,
/// was die Feier-UI (`WorkoutFeedbackView`) bzw. die "Willkommen zurück"-
/// Anzeige (`ChallengesView`) zur Darstellung braucht, statt dass die
/// Aufrufer den `RankState` vorher/nachher selbst diffen müssen.
struct RankReconciliationResult: Equatable {
    /// Netto-Änderung dieses Aufrufs (Decay + Gewinn zusammen).
    let eloDelta: Int
    let newElo: Int
    let newPeakElo: Int
    let daysDecayed: Int
    /// Betrag, der wegen `daysDecayed` abgezogen wurde (vor dem Floor bei 0).
    let decayElo: Int
    let oldTier: RankTier
    let newTier: RankTier
    let comebackActive: Bool
    let streakDays: Int
    let newLastProcessedDay: Date
    /// `true`, wenn diese Reconciliation Basis-/Streak-Bonus vergeben hat
    /// (erste Session eines Kalendertags) - Grundlage dafür, Meilenstein-
    /// Feiern (Confetti) nicht bei jeder weiteren Session desselben Tages
    /// erneut auszulösen (siehe `WorkoutFeedbackView`).
    let awardedDailyBonus: Bool
}

/// Reine, zustandslose Elo-/Rang-Berechnung (analog `ChallengeInsights`) -
/// kein `ModelContext`, alle Eingaben injiziert, deterministisch testbar.
enum RankEngine {
    static func tier(forElo elo: Int) -> RankTier {
        RankTuning.tierThresholds.reversed().first { elo >= $0.minElo }?.tier ?? .bronze
    }

    /// Fortschritt innerhalb der aktuellen Tier-Spanne, Grundlage für den
    /// `DSProgressRing` in `RankSectionCard`. Bei `.challenger` (kein
    /// nächstes Tier) wird ein voller Ring (`1/1`) zurückgegeben statt eines
    /// undefinierten Ziels.
    static func tierProgress(forElo elo: Int) -> (value: Int, max: Int) {
        let thresholds = RankTuning.tierThresholds
        guard let currentIndex = thresholds.firstIndex(where: { $0.tier == tier(forElo: elo) }) else {
            return (value: 0, max: 1)
        }
        let currentThreshold = thresholds[currentIndex].minElo
        guard currentIndex + 1 < thresholds.count else {
            return (value: 1, max: 1)
        }
        let nextThreshold = thresholds[currentIndex + 1].minElo
        return (value: elo - currentThreshold, max: nextThreshold - currentThreshold)
    }

    /// Globale Tages-Streak über ALLE abgeschlossenen Sessions (Kraft und
    /// Cardio gleichermaßen), unabhängig von Challenge-Beitritt - delegiert
    /// die Kernlogik an `DayStreakCalculator`, dieselbe Rückwärtslauf-
    /// Berechnung wie `ChallengeInsights.currentStreakDays`.
    static func globalStreakDays(from sessions: [WorkoutSession], calendar: Calendar = .current, today: Date = .now) -> Int {
        let uniqueDays = Set(sessions.filter { $0.endDate != nil }.map { calendar.startOfDay(for: $0.startDate) })
        return DayStreakCalculator.currentStreak(uniqueDays: uniqueDays, calendar: calendar, today: today)
    }

    /// Überlastungs-Bonus: relative Volumensteigerung je Übung ggü. dem
    /// letzten passenden Vorversuch (nicht absolut - eine 20×10kg- und eine
    /// 5×80kg-Übung werden bei gleicher %-Steigerung gleich behandelt, ADR
    /// 0014). Übungen ohne Vorwert oder mit Rückgang tragen nichts bei.
    static func overloadBonus(
        currentVolumeByExercise: [String: Double],
        previousVolumeByExercise: [String: Double]
    ) -> Int {
        var total = 0
        for (exerciseName, currentVolume) in currentVolumeByExercise {
            guard let previousVolume = previousVolumeByExercise[exerciseName], previousVolume > 0 else { continue }
            let increasePercent = (currentVolume - previousVolume) / previousVolume * 100
            guard increasePercent > 0 else { continue }
            let steps = Int((increasePercent / RankTuning.overloadStepPercent).rounded(.up))
            total += min(steps * RankTuning.overloadStepElo, RankTuning.overloadPerExerciseCap)
        }
        return min(total, RankTuning.overloadSessionCap)
    }

    /// Zentrale Reconciliation - einziger Ort, an dem Elo-Gewinn UND
    /// Inaktivitäts-Decay berechnet werden.
    ///
    /// Schlüssel-Invariante: jeder Aufruf (auch am selben Tag) aktualisiert
    /// `lastProcessedDay` konsistent, daher ist jeder Tag STRIKT zwischen
    /// `lastProcessedDay` und `today` garantiert session-frei - sonst hätte
    /// eine frühere Reconciliation `lastProcessedDay` schon vorangetrieben.
    /// Der Decay für diese Lücke ist deshalb reine Arithmetik
    /// (`missedDays * inactivityDecayPerDay`), kein Tag-für-Tag-Loop nötig -
    /// mathematisch identisch, da der Floor bei 0 monoton ist und sich nicht
    /// durch eine Schleife "rückgängig machen" ließe.
    ///
    /// Bei reiner Decay-Nachholung (`sessionCompletedToday == false`) rückt
    /// `lastProcessedDay` nur bis "gestern" vor, nie bis "heute" - der
    /// heutige Tag ist noch offen (könnte später noch eine Session bekommen).
    /// Das macht wiederholte Aufrufe am selben Tag idempotent.
    static func reconcile(
        currentElo: Int,
        peakElo: Int,
        lastProcessedDay: Date,
        today: Date,
        calendar: Calendar = .current,
        currentStreakDays: Int = 0,
        sessionCompletedToday: Bool,
        overloadBonusThisSession: Int = 0
    ) -> RankReconciliationResult {
        let todayStart = calendar.startOfDay(for: today)
        let lastStart = calendar.startOfDay(for: lastProcessedDay)
        // Schützt die Monotonie-Invariante, auf der die Decay-Nachholung
        // aufbaut: `today` kann durch eine spät abgeschlossene, vor
        // `lastProcessedDay` GESTARTETE Session (Trigger 1 reconciled auf
        // `startDate`, Trigger 2 auf echtes `.now` - eine über Mitternacht
        // laufende Session kann so hinter einer bereits von Trigger 2
        // verarbeiteten Lücke liegen) vor `lastProcessedDay` zurückfallen.
        // Ohne diesen Clamp würde `newLastProcessedDay` weiter unten auf
        // einen älteren Tag zurückgesetzt - ein bereits verarbeiteter Tag
        // würde beim nächsten Aufruf erneut als verpasst gezählt (Doppel-
        // Decay) statt nur diese eine (verspätete) Session ohne Tages-Bonus
        // zu belassen.
        let effectiveTodayStart = max(todayStart, lastStart)
        let daysBetween = max(0, calendar.dateComponents([.day], from: lastStart, to: effectiveTodayStart).day ?? 0)
        let oldTier = tier(forElo: currentElo)

        let missedDays = max(0, daysBetween - 1)
        let decayElo = missedDays * RankTuning.inactivityDecayPerDay
        let eloAfterDecay = max(0, currentElo - decayElo)

        let gain: Int
        let comebackActive: Bool
        let newLastProcessedDay: Date
        let awardedDailyBonus: Bool

        if sessionCompletedToday {
            let isFirstSessionToday = daysBetween >= 1
            let base = isFirstSessionToday ? RankTuning.baseDailyBonus : 0
            let streakBoost = isFirstSessionToday
                ? min(currentStreakDays * RankTuning.streakBoostPerDay, RankTuning.streakBoostCap)
                : 0
            let sum = base + streakBoost + overloadBonusThisSession
            comebackActive = eloAfterDecay < peakElo && currentStreakDays >= RankTuning.comebackStreakThreshold
            gain = comebackActive ? sum * RankTuning.comebackMultiplier : sum
            newLastProcessedDay = effectiveTodayStart
            awardedDailyBonus = isFirstSessionToday
        } else {
            gain = 0
            comebackActive = false
            awardedDailyBonus = false
            newLastProcessedDay = daysBetween > 0
                ? (calendar.date(byAdding: .day, value: -1, to: effectiveTodayStart) ?? lastStart)
                : lastStart
        }

        let newElo = eloAfterDecay + gain
        let newPeakElo = max(peakElo, newElo)

        return RankReconciliationResult(
            eloDelta: newElo - currentElo,
            newElo: newElo,
            newPeakElo: newPeakElo,
            daysDecayed: missedDays,
            decayElo: decayElo,
            oldTier: oldTier,
            newTier: tier(forElo: newElo),
            comebackActive: comebackActive,
            streakDays: currentStreakDays,
            newLastProcessedDay: newLastProcessedDay,
            awardedDailyBonus: awardedDailyBonus
        )
    }
}
