import Testing
import SwiftData
import Foundation
@testable import WorkoutTracker

// Wichtig (siehe ADR 0001, Nachtrag, und docs/journal.md für die volle
// Debugging-Geschichte): Ein `ModelContext` hält seinen `ModelContainer`
// nicht selbst am Leben. Wird aus einer Hilfsfunktion nur `container.mainContext`
// zurückgegeben, ohne dass der Aufrufer `container` selbst weiter referenziert,
// wird dieser dealloziert und der zurückgegebene Context zeigt auf einen
// bereits freigegebenen Store - der Crash tritt beim ersten `insert`/`save`
// auf (reproduzierbar sowohl unter XCTest als auch unter Swift Testing).
// Deshalb hält jede Testfunktion hier ihren `container` explizit im eigenen
// Scope, nicht nur den daraus abgeleiteten Context.
@MainActor
private func makeInMemoryContainer() throws -> ModelContainer {
    try ModelContainer(
        for: Schema(versionedSchema: SchemaV1.self),
        migrationPlan: WorkoutTrackerMigrationPlan.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
}

@MainActor
struct ModelTests {
    @Test func seedingPopulatesCatalogExactlyOnce() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        UserDefaults.standard.removeObject(forKey: "exerciseCatalogSeededV1")
        defer { UserDefaults.standard.removeObject(forKey: "exerciseCatalogSeededV1") }

        await ExerciseSeeder.seedIfNeeded(in: context)
        let firstCount = try context.fetchCount(FetchDescriptor<Exercise>())
        #expect(firstCount > 0)

        await ExerciseSeeder.seedIfNeeded(in: context)
        let secondCount = try context.fetchCount(FetchDescriptor<Exercise>())
        #expect(firstCount == secondCount, "Zweiter Seed-Aufruf darf den Katalog nicht erneut befüllen")
    }

    @Test func deletingWorkoutSessionCascadesSetLogsAndProgressEntries() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let exercise = Exercise(name: "Testübung")
        context.insert(exercise)

        let session = WorkoutSession(activityType: .kraft)
        context.insert(session)
        let setLog = SetLog(setIndex: 0, exercise: exercise, reps: 10, weightKg: 20)
        setLog.session = session
        context.insert(setLog)

        let challenge = Challenge(name: "Testchallenge", challengeType: .streakTage, targetValue: 7)
        context.insert(challenge)
        let progressEntry = ChallengeProgressEntry(value: 1, challenge: challenge, triggeringSession: session)
        context.insert(progressEntry)

        try context.save()

        context.delete(session)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<SetLog>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<ChallengeProgressEntry>()) == 0)
    }

    @Test func deletingExerciseNullifiesReferencesButKeepsNameSnapshot() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let exercise = Exercise(name: "Kniebeuge")
        context.insert(exercise)

        let session = WorkoutSession(activityType: .kraft)
        context.insert(session)
        let setLog = SetLog(setIndex: 0, exercise: exercise, reps: 5, weightKg: 60)
        setLog.session = session
        context.insert(setLog)

        let plan = WorkoutPlan(name: "Testplan")
        context.insert(plan)
        let plannedExercise = PlannedExercise(orderIndex: 0, exercise: exercise, targetSets: 3, targetReps: 5)
        plannedExercise.plan = plan
        context.insert(plannedExercise)

        try context.save()

        context.delete(exercise)
        try context.save()

        #expect(setLog.exercise == nil)
        #expect(setLog.exerciseName == "Kniebeuge")
        #expect(plannedExercise.exercise == nil)
        #expect(plannedExercise.exerciseName == "Kniebeuge")
    }

    @Test func deletingWorkoutPlanNullifiesSessionButKeepsSession() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let plan = WorkoutPlan(name: "Testplan")
        context.insert(plan)

        let session = WorkoutSession(activityType: .kraft, plan: plan)
        context.insert(session)

        try context.save()

        context.delete(plan)
        try context.save()

        #expect(session.plan == nil)
        #expect(try context.fetchCount(FetchDescriptor<WorkoutSession>()) == 1, "Session darf durch Plan-Löschung nicht mitgelöscht werden")
    }

    @Test func deletingChallengeCascadesEnrollmentsAndProgressEntries() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let challenge = Challenge(name: "Testchallenge", challengeType: .frequenzProWoche, targetValue: 3)
        context.insert(challenge)

        let enrollment = ChallengeEnrollment(challenge: challenge)
        context.insert(enrollment)

        let session = WorkoutSession(activityType: .laufen)
        context.insert(session)
        let progressEntry = ChallengeProgressEntry(value: 1, challenge: challenge, triggeringSession: session)
        context.insert(progressEntry)

        try context.save()

        context.delete(challenge)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<ChallengeEnrollment>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<ChallengeProgressEntry>()) == 0)
    }
}
