import Foundation
import SwiftData

/// Hält den UI-Status der HealthKit-Verbindung. Der tatsächliche
/// Autorisierungsstatus lebt in Apple Health selbst - `hasRequestedAuthorization`
/// wird deshalb bei jeder Instanziierung aus `healthKitService.isAuthorized()`
/// initialisiert, statt naiv bei `false` zu starten. Sonst zeigt der Screen
/// nach jedem App-Neustart fälschlich "Nicht verbunden", obwohl die
/// Berechtigung beim Betriebssystem längst erteilt ist.
@Observable
@MainActor
final class SettingsViewModel {
    private let healthKitService: HealthKitServicing

    private(set) var isRequestingAuthorization = false
    private(set) var hasRequestedAuthorization: Bool
    var authorizationErrorMessage: String?

    init(healthKitService: HealthKitServicing = HealthKitService()) {
        self.healthKitService = healthKitService
        self.hasRequestedAuthorization = healthKitService.isAuthorized()
    }

    func connectToHealth() async {
        isRequestingAuthorization = true
        authorizationErrorMessage = nil
        defer { isRequestingAuthorization = false }
        do {
            try await healthKitService.requestAuthorization()
            hasRequestedAuthorization = healthKitService.isAuthorized()
        } catch {
            authorizationErrorMessage = "Verbindung zu Apple Health fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    #if DEBUG
    /// Bewusster Einmal-Vorgang: trägt die kcal-Schätzung nachträglich für
    /// die zuletzt beendete, bereits in Health gespeicherte Kraft-Session
    /// nach (für Sessions, die vor Einführung der kcal-Schätzung
    /// abgeschlossen wurden). Kein dauerhaftes Backfill-Feature - Methode
    /// und Button nach einmaliger Nutzung in einem Folge-Commit wieder
    /// entfernen.
    func backfillMostRecentStrengthSessionEnergyEstimate(context: ModelContext) async {
        var descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.healthKitUUID != nil }
        )
        descriptor.sortBy = [SortDescriptor(\.startDate, order: .reverse)]

        guard
            let sessions = try? context.fetch(descriptor),
            let session = sessions.first(where: { $0.activityType == .kraft }),
            let healthKitUUID = session.healthKitUUID
        else { return }

        let totalVolumeKg = session.setLogs
            .filter(\.isCompleted)
            .reduce(0.0) { $0 + Double($1.reps) * $1.weightKg }

        guard
            let bodyWeightKg = try? await healthKitService.fetchLatestBodyWeightKg(),
            let kcal = EnergyEstimator.estimatedActiveEnergyKcal(
                totalVolumeKg: totalVolumeKg,
                bodyWeightKg: bodyWeightKg,
                duration: (session.endDate ?? .now).timeIntervalSince(session.startDate)
            ),
            // attachEnergy() ist bewusst kein Teil von HealthKitServicing
            // (siehe HealthKitService.swift) - dieser Downcast betrifft nur
            // diesen Einmal-Backfill, der ohnehin wieder entfernt wird.
            let realHealthKitService = healthKitService as? HealthKitService
        else { return }

        try? await realHealthKitService.attachEnergy(kcal: kcal, toWorkoutWithHealthKitUUID: healthKitUUID)
    }
    #endif
}
