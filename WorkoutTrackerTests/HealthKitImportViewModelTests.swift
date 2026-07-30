import Testing
import SwiftData
import Foundation
@testable import WorkoutTracker

@MainActor
struct HealthKitImportViewModelTests {
    @Test func refreshExcludesAlreadyImportedWorkouts() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let alreadyImportedUUID = UUID()
        let existingSession = WorkoutSession(
            activityType: .laufen,
            source: .healthKitImport,
            healthKitUUID: alreadyImportedUUID
        )
        context.insert(existingSession)
        try context.save()

        let newUUID = UUID()
        let mock = MockHealthKitService()
        mock.importableWorkouts = [
            HealthKitWorkoutSample(
                id: alreadyImportedUUID,
                hkActivityType: .running,
                start: .now.addingTimeInterval(-3600),
                end: .now,
                totalDistanceMeters: 5000,
                averageHeartRate: nil
            ),
            HealthKitWorkoutSample(
                id: newUUID,
                hkActivityType: .cycling,
                start: .now.addingTimeInterval(-1800),
                end: .now,
                totalDistanceMeters: 10000,
                averageHeartRate: nil
            ),
        ]

        let viewModel = HealthKitImportViewModel(context: context, healthKitService: mock)
        await viewModel.refresh()

        #expect(viewModel.importableWorkouts.map(\.id) == [newUUID])
    }

    @Test func importSessionCreatesSegmentBasedCardioSession() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let sampleUUID = UUID()
        let sample = HealthKitWorkoutSample(
            id: sampleUUID,
            hkActivityType: .cycling,
            start: Date(timeIntervalSinceNow: -3600),
            end: .now,
            totalDistanceMeters: 12000,
            averageHeartRate: 132
        )

        let viewModel = HealthKitImportViewModel(context: context, healthKitService: MockHealthKitService())
        viewModel.importSession(sample)

        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        #expect(sessions.count == 1)
        let session = try #require(sessions.first)
        #expect(session.source == .healthKitImport)
        #expect(session.healthKitUUID == sampleUUID)
        #expect(session.activityType == .radfahren)
        #expect(session.averageHeartRate == 132)
        #expect(session.segmentLogs.count == 1)
        #expect(session.segmentLogs.first?.distanceMeters == 12000)
    }

    @Test func importSessionRemovesImportedSampleFromList() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let mock = MockHealthKitService()
        let sample = HealthKitWorkoutSample(
            id: UUID(),
            hkActivityType: .running,
            start: Date(timeIntervalSinceNow: -1800),
            end: .now,
            totalDistanceMeters: 4000,
            averageHeartRate: nil
        )
        mock.importableWorkouts = [sample]

        let viewModel = HealthKitImportViewModel(context: context, healthKitService: mock)
        await viewModel.refresh()
        #expect(viewModel.importableWorkouts.count == 1)

        viewModel.importSession(sample)
        #expect(viewModel.importableWorkouts.isEmpty)
    }

    @Test func importSessionUpdatesRankProgress() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let sample = HealthKitWorkoutSample(
            id: UUID(),
            hkActivityType: .running,
            start: Date(timeIntervalSinceNow: -1800),
            end: .now,
            totalDistanceMeters: 4000,
            averageHeartRate: nil
        )

        let viewModel = HealthKitImportViewModel(context: context, healthKitService: MockHealthKitService())
        viewModel.importSession(sample)

        let rankState = RankState.fetchOrCreate(in: context)
        #expect(rankState.currentElo == 16, "Importierte Sessions müssen genauso wie lokal beendete den Rang-Fortschritt aktualisieren (15 Basis + 1 Streak-Tag)")
    }
}
