import HealthKit

enum HealthKitServiceError: Error {
    case healthDataUnavailable
    case attachEnergyFailed
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
        [HKObjectType.workoutType(), HKQuantityType(.activeEnergyBurned)]
    }

    private var readTypes: Set<HKObjectType> {
        [
            HKObjectType.workoutType(),
            HKQuantityType(.heartRate),
            HKQuantityType(.distanceCycling),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.bodyMass),
        ]
    }

    /// `authorizationStatus(for:)` liefert nur für "Share"-Typen ein
    /// verlässliches Signal (Datenschutz: Lesezugriff wird nie verraten).
    /// `activeEnergyBurned` ist ein zweiter, unabhängig autorisierbarer
    /// Share-Type (kcal-Schätzung) - "verbunden" bleibt aber bewusst am
    /// primären `workoutType()`-Signal festgemacht, nicht an beiden.
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
        let energyQuantity = session.activeEnergyKcal.map { HKQuantity(unit: .kilocalorie(), doubleValue: $0) }
        let workout = HKWorkout(
            activityType: HealthKitActivityMapping.hkActivityType(for: session.activityType),
            start: session.start,
            end: session.end,
            workoutEvents: nil,
            totalEnergyBurned: energyQuantity,
            totalDistance: nil,
            metadata: nil
        )
        try await healthStore.save(workout)
        return workout.uuid
    }

    func fetchLatestBodyWeightKg() async throws -> Double? {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(.bodyMass))],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
            limit: 1
        )
        let samples = try await descriptor.result(for: healthStore)
        return samples.first?.quantity.doubleValue(for: .gramUnit(with: .kilo))
    }

    /// Bewusst NICHT Teil von `HealthKitServicing` - dient ausschließlich dem
    /// einmaligen DEBUG-Backfill in `SettingsViewModel` (siehe dort), der
    /// nach einmaliger Nutzung wieder entfernt wird. Ein dauerhafter,
    /// gemeinsam von echtem Service und Mock zu tragender Protokoll-Vertrag
    /// wäre für diesen Einmal-Zweck unverhältnismäßig (YAGNI).
    func attachEnergy(kcal: Double, toWorkoutWithHealthKitUUID healthKitUUID: UUID) async throws {
        let predicate = HKQuery.predicateForObject(with: healthKitUUID)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: []
        )
        guard let workout = try await descriptor.result(for: healthStore).first else { return }

        let sample = HKQuantitySample(
            type: HKQuantityType(.activeEnergyBurned),
            quantity: HKQuantity(unit: .kilocalorie(), doubleValue: kcal),
            start: workout.startDate,
            end: workout.endDate
        )
        try await healthStore.save(sample)
        // `add(_:to:completion:)` ist seit macOS 14/iOS 17 als API zugunsten
        // von `HKWorkoutBuilder` deprecated, hat aber keine async-Variante
        // (einzige Stelle im Projekt, die einen Continuation-Wrapper
        // braucht) - `HKWorkoutBuilder` erzeugt jedoch nur neue Workouts,
        // kann einem bereits gespeicherten `HKWorkout` nicht nachträglich
        // eine Angabe hinzufügen. Für dieses Einmal-Backfill bleibt die
        // deprecated API bewusst die einzig anwendbare (bei Neuanlage wird
        // totalEnergyBurned stattdessen direkt im HKWorkout-Init übergeben,
        // siehe oben - dort kommt die deprecated API nicht zum Einsatz).
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.add([sample], to: workout) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthKitServiceError.attachEnergyFailed)
                }
            }
        }
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
