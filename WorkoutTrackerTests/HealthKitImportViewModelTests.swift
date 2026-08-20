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

    @Test func importAllSessionsImportsEveryWorkoutAndClearsList() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let mock = MockHealthKitService()
        mock.importableWorkouts = descendingSamplesOnConsecutiveDays()

        let viewModel = HealthKitImportViewModel(context: context, healthKitService: mock)
        await viewModel.refresh()
        #expect(viewModel.importableWorkouts.count == 3)

        viewModel.importAllSessions()

        #expect(try context.fetch(FetchDescriptor<WorkoutSession>()).count == 3)
        #expect(viewModel.importableWorkouts.isEmpty)
    }

    /// Sichert die Sortier-Entscheidung in `importAllSessions()` ab: ohne das
    /// Umdrehen der (absteigenden) Listenreihenfolge bekämen die älteren
    /// Importe wegen des Monotonie-Clamps in `RankEngine.reconcile` weder
    /// Tages-Bonus noch Streak-Boost, und der Elo-Wert fiele auf den einer
    /// einzelnen Session zurück.
    @Test func importAllSessionsAwardsDailyBonusPerTrainingDay() async throws {
        let samples = descendingSamplesOnConsecutiveDays()

        let bulkContainer = try makeInMemoryContainer()
        let mock = MockHealthKitService()
        mock.importableWorkouts = samples
        let bulkViewModel = HealthKitImportViewModel(
            context: bulkContainer.mainContext,
            healthKitService: mock
        )
        await bulkViewModel.refresh()
        bulkViewModel.importAllSessions()

        let singleContainer = try makeInMemoryContainer()
        let singleViewModel = HealthKitImportViewModel(
            context: singleContainer.mainContext,
            healthKitService: MockHealthKitService()
        )
        for sample in samples.reversed() {
            singleViewModel.importSession(sample)
        }

        // Referenz: nur das jüngste Sample importiert - der Wert, auf den der
        // Bulk-Import ohne aufsteigende Sortierung zurückfiele.
        let singleDayContainer = try makeInMemoryContainer()
        HealthKitImportViewModel(
            context: singleDayContainer.mainContext,
            healthKitService: MockHealthKitService()
        ).importSession(samples[0])

        let bulkElo = RankState.fetchOrCreate(in: bulkContainer.mainContext).currentElo
        let singleElo = RankState.fetchOrCreate(in: singleContainer.mainContext).currentElo
        let singleDayElo = RankState.fetchOrCreate(in: singleDayContainer.mainContext).currentElo
        #expect(bulkElo == singleElo)
        #expect(bulkElo > singleDayElo)
    }

    /// Ergänzt den Test darüber um die Konfiguration, die im echten Betrieb
    /// überwiegt: sobald der Challenges-Tab einmal offen war, steht
    /// `lastProcessedDay` auf gestern (siehe
    /// `RankReconciliation.reconcileDecayOnly`). Dann bekommt nur noch ein
    /// Sample von heute einen Tages-Bonus - der Bulk-Import bleibt aber auch
    /// hier deckungsgleich mit Einzelimports von alt nach neu, und genau das
    /// ist die Zusage: er bildet die Rang-Logik ab, statt sie zu erweitern.
    @Test func importAllSessionsMatchesSingleImportsWithExistingRankState() async throws {
        let samples = descendingSamplesOnConsecutiveDays()

        let bulkContainer = try makeInMemoryContainer()
        seedRankStateAnchoredYesterday(in: bulkContainer.mainContext)
        let mock = MockHealthKitService()
        mock.importableWorkouts = samples
        let bulkViewModel = HealthKitImportViewModel(
            context: bulkContainer.mainContext,
            healthKitService: mock
        )
        await bulkViewModel.refresh()
        bulkViewModel.importAllSessions()

        let singleContainer = try makeInMemoryContainer()
        seedRankStateAnchoredYesterday(in: singleContainer.mainContext)
        let singleViewModel = HealthKitImportViewModel(
            context: singleContainer.mainContext,
            healthKitService: MockHealthKitService()
        )
        for sample in samples.reversed() {
            singleViewModel.importSession(sample)
        }

        #expect(
            RankState.fetchOrCreate(in: bulkContainer.mainContext).currentElo
                == RankState.fetchOrCreate(in: singleContainer.mainContext).currentElo
        )
    }

    /// `fetchOrCreate` legt eine frische Zeile mit `lastProcessedDay == gestern`
    /// an - derselbe Zustand, den der erste Besuch des Challenges-Tabs
    /// hinterlässt.
    private func seedRankStateAnchoredYesterday(in context: ModelContext) {
        _ = RankState.fetchOrCreate(in: context)
        try? context.save()
    }

    /// Drei Workouts an drei aufeinanderfolgenden Kalendertagen, neueste
    /// zuerst - so wie `fetchImportableCardioWorkouts` sie liefert.
    private func descendingSamplesOnConsecutiveDays() -> [HealthKitWorkoutSample] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return (0...2).map { daysAgo in
            let start = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
                .addingTimeInterval(10 * 3600)
            return HealthKitWorkoutSample(
                id: UUID(),
                hkActivityType: .running,
                start: start,
                end: start.addingTimeInterval(1800),
                totalDistanceMeters: 4000,
                averageHeartRate: nil
            )
        }
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
