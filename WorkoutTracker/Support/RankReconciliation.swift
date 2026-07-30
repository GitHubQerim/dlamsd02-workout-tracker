import Foundation
import SwiftData

extension WorkoutSession {
    /// Trigger 1 (Session-Abschluss): holt/erzeugt den Singleton-`RankState`,
    /// berechnet globale Streak + Überlastungs-Bonus (nur Kraft, siehe ADR
    /// 0014) und ruft `RankEngine.reconcile` mit `sessionCompletedToday: true`
    /// auf. Muss NACH `endDate = .now` gesetzt und NACH
    /// `detectAndPersistPersonalRecords(in:)` aufgerufen werden (gleicher
    /// Aufrufpunkt-Stil wie die Challenge-/PR-Materialisierung in
    /// `WorkoutSessionViewModel.finishSession()`). Persistiert wird hier
    /// nicht selbst - der Aufrufer speichert einmalig über `persist()`.
    @discardableResult
    func updateRankProgress(in context: ModelContext) -> RankReconciliationResult {
        let calendar = Calendar.current
        // Trainingstag, nicht `.now` - analog `materializeChallengeProgress`.
        let trainedOn = startDate
        // `today: trainedOn` statt Default `.now`: eine frische `RankState`-
        // Zeile soll relativ zum tatsächlichen Trainingstag entstehen, nicht
        // zur echten Uhrzeit dieses Aufrufs (siehe Monotonie-Kommentar in
        // `RankEngine.reconcile`).
        let rankState = RankState.fetchOrCreate(in: context, calendar: calendar, today: trainedOn)

        // EIN Fetch für Streak UND Überlastungs-Vorwerte statt eines
        // zusätzlichen Fetches pro Übung - `allCompleted` enthält diese
        // Session bereits (ihr `endDate` ist beim Aufruf aus `finishSession()`
        // schon gesetzt).
        let allCompleted = (try? context.fetch(FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.endDate != nil }
        ))) ?? []
        let streakDays = RankEngine.globalStreakDays(from: allCompleted, calendar: calendar, today: trainedOn)

        var overload = 0
        if activityType.usesSetLogs {
            let currentVolumes = ChallengeInsights.volumeByExercise(setLogs)
            let otherCompletedByRecency = allCompleted
                .filter { $0.id != id }
                .sorted { $0.startDate > $1.startDate }

            var previousVolumes: [String: Double] = [:]
            for exerciseName in currentVolumes.keys {
                guard let previous = otherCompletedByRecency.first(where: { candidate in
                    candidate.setLogs.contains { $0.exerciseName == exerciseName }
                }) else { continue }
                previousVolumes[exerciseName] = ChallengeInsights.volumeByExercise(previous.setLogs)[exerciseName] ?? 0
            }

            overload = RankEngine.overloadBonus(
                currentVolumeByExercise: currentVolumes,
                previousVolumeByExercise: previousVolumes
            )
        }

        let result = RankEngine.reconcile(
            currentElo: rankState.currentElo,
            peakElo: rankState.peakElo,
            lastProcessedDay: rankState.lastProcessedDay,
            today: trainedOn,
            calendar: calendar,
            currentStreakDays: streakDays,
            sessionCompletedToday: true,
            overloadBonusThisSession: overload
        )

        rankState.currentElo = result.newElo
        rankState.peakElo = result.newPeakElo
        rankState.lastProcessedDay = result.newLastProcessedDay
        return result
    }
}

extension RankState {
    /// Trigger 2 (`ChallengesView.onAppear`): nur Decay-Nachholung, kein
    /// Gewinn - bei diesem Trigger existiert keine neue Session für "heute".
    /// Ergebnis dient der "Willkommen zurück"-Anzeige (verlorene Tage/Elo).
    @discardableResult
    static func reconcileDecayOnly(in context: ModelContext, calendar: Calendar = .current, today: Date = .now) -> RankReconciliationResult {
        let rankState = RankState.fetchOrCreate(in: context, calendar: calendar, today: today)
        let allCompleted = (try? context.fetch(FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.endDate != nil }
        ))) ?? []
        let streakDays = RankEngine.globalStreakDays(from: allCompleted, calendar: calendar, today: today)

        let result = RankEngine.reconcile(
            currentElo: rankState.currentElo,
            peakElo: rankState.peakElo,
            lastProcessedDay: rankState.lastProcessedDay,
            today: today,
            calendar: calendar,
            currentStreakDays: streakDays,
            sessionCompletedToday: false
        )
        rankState.currentElo = result.newElo
        rankState.lastProcessedDay = result.newLastProcessedDay
        return result
    }
}
