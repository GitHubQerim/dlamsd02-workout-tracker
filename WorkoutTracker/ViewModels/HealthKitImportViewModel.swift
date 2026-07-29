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

    /// Legt eine importierte Session mit genau einem `SegmentLog`
    /// (Gesamtdistanz/-dauer) an - kein Intervall-Splitting (Phase-E-Scope-
    /// Entscheidung).
    func importSession(_ sample: HealthKitWorkoutSample) {
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

        try? context.save()
        importableWorkouts.removeAll { $0.id == sample.id }
    }
}
