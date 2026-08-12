import Foundation
import SwiftData

/// Mutierende Aktionen für Challenges - bewusst schlank (nur `join`/`leave`),
/// keine reinen Lesewerte hier (siehe `ChallengeInsights`, das direkt auf
/// per `@Query` geladenen Arrays arbeitet, ohne ViewModel-Kopplung). Eine
/// Ausnahme: `loadMoveRingSignal()` ist async HealthKit-I/O mit Fehler-
/// Swallowing (ADR 0015), kein reiner Wert-Read - das gehört ins ViewModel,
/// nicht in die View (kein `HealthKitServicing` in Views, siehe andere
/// ViewModels dieses Projekts).
@Observable
@MainActor
final class ChallengesViewModel {
    private(set) var validationMessage: String?
    private(set) var closedMoveRingDates: Set<Date> = []

    private let context: ModelContext
    private let healthKitService: HealthKitServicing

    init(context: ModelContext, healthKitService: HealthKitServicing = HealthKitService()) {
        self.context = context
        self.healthKitService = healthKitService
    }

    /// Lädt das Move-Ring-Signal für die Heatmap nach - degradiert bei
    /// fehlendem/verweigertem HealthKit-Zugriff still zu "nur Session-
    /// Farbe", nie zu einem Fehlerbanner (analog `finishSession()`s
    /// `try?`-Pattern für `fetchLatestBodyWeightKg`, ADR 0015).
    func loadMoveRingSignal(calendar: Calendar = .current, weeks: Int = 20) async {
        guard let windowStart = calendar.date(byAdding: .day, value: -(weeks * 7 - 1), to: calendar.startOfDay(for: .now)) else { return }
        closedMoveRingDates = (try? await healthKitService.fetchClosedMoveRingDates(since: windowStart, calendar: calendar)) ?? []
    }

    /// Verhindert doppelten Beitritt zur selben Challenge - reine ViewModel-
    /// Invariante, keine DB-Constraint (gleiches Muster wie
    /// `WorkoutProgramEditorViewModel.setDefault`, ADR 0008).
    @discardableResult
    func join(_ challenge: Challenge) -> Bool {
        guard challenge.enrollments.isEmpty else {
            validationMessage = "Du bist \(challenge.name) bereits beigetreten."
            return false
        }
        let enrollment = ChallengeEnrollment(challenge: challenge)
        context.insert(enrollment)
        do {
            try context.save()
            return true
        } catch {
            validationMessage = "Beitreten fehlgeschlagen: \(error.localizedDescription)"
            return false
        }
    }

    /// Löscht nur die Anmeldung - der bisherige Fortschritts-Log bleibt
    /// bestehen (kein rückwirkendes Löschen/Zurücksetzen, siehe ADR-0002-
    /// Nachtrag Phase D).
    func leave(_ enrollment: ChallengeEnrollment) {
        context.delete(enrollment)
        do {
            try context.save()
        } catch {
            validationMessage = "Verlassen fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    /// Trigger 2 der Rang-Reconciliation (ADR 0014): reine Decay-Nachholung
    /// beim Betreten des Challenges-Tabs, kein Elo-Gewinn (keine neue
    /// Session existiert bei diesem Trigger). Mutiert über `context` hier im
    /// ViewModel statt direkt in der View (MVVM-Konvention dieses Projekts),
    /// speichert direkt wie `join`/`leave` oben (anders als die Session-
    /// Abschluss-Erweiterungen, die dem Aufrufer einen gebündelten `persist()`
    /// überlassen - hier gibt es keinen weiteren Mutationsschritt danach).
    @discardableResult
    func reconcileRankDecayOnAppear(calendar: Calendar = .current, today: Date = .now) -> RankReconciliationResult {
        let result = RankState.reconcileDecayOnly(in: context, calendar: calendar, today: today)
        do {
            try context.save()
        } catch {
            validationMessage = "Rang-Aktualisierung fehlgeschlagen: \(error.localizedDescription)"
        }
        return result
    }
}
