import Testing
import SwiftData
import Foundation
@testable import WorkoutTracker

@MainActor
struct WorkoutSessionViewModelTests {
    @Test func startFromPlanCreatesSetLogsWithTargetValues() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let exercise = Exercise(name: "Kniebeuge")
        context.insert(exercise)
        let plan = WorkoutPlan(name: "Testplan", activityType: .kraft)
        context.insert(plan)
        let plannedExercise = PlannedExercise(orderIndex: 0, exercise: exercise, targetSets: 3, targetReps: 8, targetWeightKg: 60)
        plannedExercise.plan = plan
        context.insert(plannedExercise)
        try context.save()

        let viewModel = WorkoutSessionViewModel.start(context: context, plan: plan, activityType: .kraft)

        #expect(viewModel.session.setLogs.count == 3)
        #expect(viewModel.session.setLogs.allSatisfy { $0.reps == 8 && $0.weightKg == 60 })
    }

    @Test func startWithoutPlanCreatesNoSetLogs() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let viewModel = WorkoutSessionViewModel.start(context: context, plan: nil, activityType: .laufen)

        #expect(viewModel.session.setLogs.isEmpty)
        #expect(viewModel.session.plan == nil)
    }

    @Test func toggleSetCompletionStartsRestTimer() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Kniebeuge")
        context.insert(exercise)

        let viewModel = WorkoutSessionViewModel.start(context: context, plan: nil, activityType: .kraft)
        viewModel.addSet(for: exercise, suggestedReps: 10, suggestedWeightKg: 50)
        let setLog = viewModel.session.setLogs[0]

        #expect(viewModel.isRestTimerRunning == false)
        viewModel.toggleSetCompletion(setLog)
        #expect(viewModel.isRestTimerRunning == true)
        #expect(setLog.isCompleted == true)
    }

    @Test func finishSessionSetsEndDateAndPersists() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let viewModel = WorkoutSessionViewModel.start(context: context, plan: nil, activityType: .laufen)
        viewModel.updateCardioMetrics(distanceMeters: 5000, averageHeartRate: 140)

        viewModel.finishSession()

        #expect(viewModel.session.endDate != nil)
        #expect(try context.fetchCount(FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.endDate == nil })) == 0)
    }

    @Test func discardSessionDeletesSession() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let viewModel = WorkoutSessionViewModel.start(context: context, plan: nil, activityType: .laufen)
        viewModel.discardSession()

        #expect(try context.fetchCount(FetchDescriptor<WorkoutSession>()) == 0)
    }

    @Test func exerciseSectionsFollowPlanOrderWhenPlanExists() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let exerciseA = Exercise(name: "A")
        let exerciseB = Exercise(name: "B")
        context.insert(exerciseA)
        context.insert(exerciseB)
        let plan = WorkoutPlan(name: "Testplan", activityType: .kraft)
        context.insert(plan)
        let secondPlanned = PlannedExercise(orderIndex: 1, exercise: exerciseA, targetSets: 1, targetReps: 1)
        secondPlanned.plan = plan
        context.insert(secondPlanned)
        let firstPlanned = PlannedExercise(orderIndex: 0, exercise: exerciseB, targetSets: 1, targetReps: 1)
        firstPlanned.plan = plan
        context.insert(firstPlanned)
        try context.save()

        let viewModel = WorkoutSessionViewModel.start(context: context, plan: plan, activityType: .kraft)

        #expect(viewModel.exerciseSections.map(\.name) == ["B", "A"])
    }

    @Test func exerciseSectionsFollowFirstAppearanceOrderWithoutPlan() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let exerciseA = Exercise(name: "A")
        let exerciseB = Exercise(name: "B")
        context.insert(exerciseA)
        context.insert(exerciseB)

        let viewModel = WorkoutSessionViewModel.start(context: context, plan: nil, activityType: .kraft)
        viewModel.addSet(for: exerciseB)
        viewModel.addSet(for: exerciseA)

        #expect(viewModel.exerciseSections.map(\.name) == ["B", "A"])
    }
}
