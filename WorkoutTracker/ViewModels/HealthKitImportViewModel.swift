import Foundation
import SwiftData

/// Leserichtung Health->App (ADR 0012): Dedup ausschließlich über die Menge
/// bereits vorhandener `healthKitUUID`s, kein Zeitfenster-Abgleich nötig, da
/// `HKWorkout.uuid` stabil und eindeutig ist.
@Observable
@MainActor
final class HealthKitImportViewModel {
    private let context: ModelContext
    private let healthKitService: HealthKitServicing

    private(set) var importableWorkouts: [HealthKitWorkoutSample] = []
    private(set) var isRefreshing = false
    var errorMessage: String?

    init(context: ModelContext, healthKitService: HealthKitServicing = HealthKitService()) {
        self.context = context
        self.healthKitService = healthKitService
    }

    func refresh() async {
        isRefreshing = true
        errorMessage = nil
        defer { isRefreshing = false }
        do {
            let existingUUIDs = try fetchExistingHealthKitUUIDs()
            importableWorkouts = try await healthKitService.fetchImportableCardioWorkouts(excluding: existingUUIDs)
        } catch {
            errorMessage = "Import konnte nicht geladen werden: \(error.localizedDescription)"
        }
    }

    private func fetchExistingHealthKitUUIDs() throws -> Set<UUID> {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.healthKitUUID != nil }
        )
        return Set(try context.fetch(descriptor).compactMap(\.healthKitUUID))
    }

    /// Importiert genau ein Sample. Speichern, Listen- und Widget-Auffrischung
    /// bleiben hier (und nicht in `insertSession`), damit `importAllSessions()`
    /// sie einmalig statt pro Sample ausführen kann.
    func importSession(_ sample: HealthKitWorkoutSample) {
        insertSession(from: sample)
        try? context.save()
        importableWorkouts.removeAll { $0.id == sample.id }
        WidgetSnapshotRefresher.refresh(context: context)
    }

    /// Importiert die gesamte Liste in einem Schritt - bei einem Fetch-Limit
    /// von 100 Workouts ist Einzelimport für eine ganze Historie unzumutbar.
    ///
    /// Aufsteigend nach `start`, obwohl die Liste absteigend vorliegt: der
    /// Rang-Fortschritt klemmt den verarbeiteten Tag auf `lastProcessedDay`
    /// (Monotonie-Clamp in `RankEngine.reconcile`). In Listenreihenfolge
    /// (neueste zuerst) setzte das erste Sample `lastProcessedDay` auf seinen
    /// Tag, und jedes ältere liefe danach mit `daysBetween == 0` - ohne
    /// Tages-Bonus, ohne Streak-Boost.
    ///
    /// Die Reihenfolge ist damit nie schlechter, aber auch nicht in jeder
    /// Lage besser: steht `lastProcessedDay` bereits auf gestern - jeder
    /// Besuch des Challenges-Tabs setzt ihn dorthin, siehe
    /// `RankReconciliation.reconcileDecayOnly` - bekommt ohnehin nur ein
    /// Sample von heute einen Tages-Bonus. Der Sort zahlt sich vor allem
    /// beim Erstimport aus, bevor ein `RankState` existiert. Beides ist
    /// exakt das Verhalten von Einzelimports von alt nach neu: der
    /// Bulk-Import bildet die Rang-Logik ab, er erweitert sie nicht.
    func importAllSessions() {
        errorMessage = nil
        // `insertSession` reconciled pro Sample und fetcht dabei jeweils die
        // gesamte abgeschlossene Historie. Bei 100 Samples ist das spürbar,
        // aber bewusst in Kauf genommen: Einzel- und Bulk-Import teilen sich
        // dieselbe Anlage-Logik, statt für den Bulk-Fall eine zweite,
        // abweichende Rang-Berechnung zu pflegen.
        for sample in importableWorkouts.sorted(by: { $0.start < $1.start }) {
            insertSession(from: sample)
        }

        do {
            try context.save()
        } catch {
            // Anders als beim Einzelimport kostet ein fehlgeschlagenes
            // Speichern hier den gesamten Stapel. Die Liste bleibt deshalb
            // stehen (erneuter Versuch möglich), und die noch ungespeicherten
            // Inserts werden verworfen - sonst läse der Widget-Snapshot sie
            // aus demselben Context als vermeintlich echte Sessions aus.
            context.rollback()
            errorMessage = "Import fehlgeschlagen: \(error.localizedDescription)"
            return
        }

        importableWorkouts.removeAll()
        WidgetSnapshotRefresher.refresh(context: context)
    }

    /// Legt eine importierte Session mit genau einem `SegmentLog`
    /// (Gesamtdistanz/-dauer) an - kein Intervall-Splitting (Phase-E-Scope-
    /// Entscheidung).
    private func insertSession(from sample: HealthKitWorkoutSample) {
        let activityType = HealthKitActivityMapping.activityType(for: sample.hkActivityType)
        let session = WorkoutSession(
            activityType: activityType,
            startDate: sample.start,
            endDate: sample.end,
            source: .healthKitImport,
            healthKitUUID: sample.id
        )
        session.averageHeartRate = sample.averageHeartRate
        context.insert(session)

        let segmentLog = SegmentLog(
            orderIndex: 0,
            label: activityType.displayName,
            distanceMeters: sample.totalDistanceMeters,
            durationSeconds: sample.end.timeIntervalSince(sample.start),
            isCompleted: true
        )
        segmentLog.session = session
        context.insert(segmentLog)

        // Importierte Sessions sind genauso "abgeschlossen" wie lokal
        // beendete - ohne diesen Aufruf würde die Streak (die aus der
        // Session-Historie lebt) einen importierten Trainingstag zeigen,
        // während der Rang/Decay-Zustand (der nur bei Session-Abschluss
        // reconciled wird) davon nichts weiß - siehe ADR 0014.
        session.updateRankProgress(in: context)
    }
}
