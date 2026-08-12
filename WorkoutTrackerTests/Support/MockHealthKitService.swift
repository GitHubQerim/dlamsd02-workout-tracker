@testable import WorkoutTracker
import Foundation

/// Erstes Protocol+Mock-Muster im Projekt (ADR 0011) - bisherige Tests
/// (siehe `TestSupport.swift`) testen SwiftData immer real in-memory statt
/// gemockt; für HealthKit ist ein Mock nötig, weil kein echter
/// `HKHealthStore`-Zugriff in Unit-Tests/CI verfügbar ist.
/// `@unchecked Sendable`: nur innerhalb einzelner Testfälle verwendet, nie
/// tatsächlich von mehreren Tasks/Actors gleichzeitig mutiert.
final class MockHealthKitService: HealthKitServicing, @unchecked Sendable {
    private(set) var requestAuthorizationCallCount = 0
    private(set) var savedSessions: [HealthKitOutgoingSession] = []
    private(set) var deletedUUIDs: [UUID] = []

    var authorizationError: Error?
    var saveError: Error?
    var deleteError: Error?
    var savedSessionUUID = UUID()
    var importableWorkouts: [HealthKitWorkoutSample] = []
    var isAuthorizedOverride = false
    var bodyWeightKgOverride: Double?
    var bodyWeightError: Error?
    var closedMoveRingDatesOverride: Set<Date> = []
    var moveRingError: Error?

    func isAuthorized() -> Bool {
        isAuthorizedOverride
    }

    func requestAuthorization() async throws {
        requestAuthorizationCallCount += 1
        if let authorizationError { throw authorizationError }
    }

    @discardableResult
    func saveStrengthSession(_ session: HealthKitOutgoingSession) async throws -> UUID {
        if let saveError { throw saveError }
        savedSessions.append(session)
        return savedSessionUUID
    }

    func deleteSession(healthKitUUID: UUID) async throws {
        if let deleteError { throw deleteError }
        deletedUUIDs.append(healthKitUUID)
    }

    func fetchImportableCardioWorkouts(excluding existingUUIDs: Set<UUID>) async throws -> [HealthKitWorkoutSample] {
        importableWorkouts.filter { !existingUUIDs.contains($0.id) }
    }

    func fetchLatestBodyWeightKg() async throws -> Double? {
        if let bodyWeightError { throw bodyWeightError }
        return bodyWeightKgOverride
    }

    func fetchClosedMoveRingDates(since: Date, calendar: Calendar) async throws -> Set<Date> {
        if let moveRingError { throw moveRingError }
        return closedMoveRingDatesOverride
    }
}
