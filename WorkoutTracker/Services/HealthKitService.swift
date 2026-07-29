import HealthKit

enum HealthKitServiceError: Error {
    case healthDataUnavailable
}

/// Reale `HKHealthStore`-Implementierung von `HealthKitServicing` (ADR 0011).
/// Hält `healthStore` als echten Instanz-State - der bewusste, dokumentierte
/// Stil-Bruch gegenüber den sonst zustandslosen `Support/`-Extensions.
/// `@unchecked Sendable`: `healthStore` ist ein `let` und wird nach `init`
/// nie mutiert, `HKHealthStore` ist unter der Haube threadsicher - der
/// Compiler kann das nur nicht automatisch verifizieren.
final class HealthKitService: HealthKitServicing, @unchecked Sendable {
    private let healthStore = HKHealthStore()

    private var shareTypes: Set<HKSampleType> {
        [HKObjectType.workoutType()]
    }

    private var readTypes: Set<HKObjectType> {
        [
            HKObjectType.workoutType(),
            HKQuantityType(.heartRate),
            HKQuantityType(.distanceCycling),
            HKQuantityType(.distanceWalkingRunning),
        ]
    }

    /// `authorizationStatus(for:)` liefert nur für "Share"-Typen ein
    /// verlässliches Signal (Datenschutz: Lesezugriff wird nie verraten) -
    /// `workoutType()` ist unser einziger Share-Typ, daher ausreichend.
    func isAuthorized() -> Bool {
        healthStore.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized
    }

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitServiceError.healthDataUnavailable
        }
        try await healthStore.requestAuthorization(toShare: shareTypes, read: readTypes)
    }

    @discardableResult
    func saveStrengthSession(_ session: HealthKitOutgoingSession) async throws -> UUID {
        let workout = HKWorkout(
            activityType: HealthKitActivityMapping.hkActivityType(for: session.activityType),
            start: session.start,
            end: session.end
        )
        try await healthStore.save(workout)
        return workout.uuid
    }

    func deleteSession(healthKitUUID: UUID) async throws {
        let predicate = HKQuery.predicateForObject(with: healthKitUUID)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: []
        )
        guard let sample = try await descriptor.result(for: healthStore).first else { return }
        try await healthStore.delete(sample)
    }

    func fetchImportableCardioWorkouts(excluding existingUUIDs: Set<UUID>) async throws -> [HealthKitWorkoutSample] {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout()],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
            limit: 100
        )
        let workouts = try await descriptor.result(for: healthStore)

        return workouts.compactMap { workout in
            guard workout.workoutActivityType != .traditionalStrengthTraining else { return nil }
            guard !existingUUIDs.contains(workout.uuid) else { return nil }
            let distanceType: HKQuantityType? = switch workout.workoutActivityType {
            case .cycling: HKQuantityType(.distanceCycling)
            case .running, .walking, .hiking: HKQuantityType(.distanceWalkingRunning)
            default: nil
            }
            return HealthKitWorkoutSample(
                id: workout.uuid,
                hkActivityType: HealthKitActivityMapping.activityKind(for: workout.workoutActivityType),
                start: workout.startDate,
                end: workout.endDate,
                totalDistanceMeters: distanceType.flatMap { workout.statistics(for: $0)?.sumQuantity()?.doubleValue(for: .meter()) },
                averageHeartRate: nil
            )
        }
    }
}
