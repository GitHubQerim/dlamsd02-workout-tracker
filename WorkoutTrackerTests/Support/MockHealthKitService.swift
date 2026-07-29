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
}
