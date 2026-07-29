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
        let plan = Workout(name: "Testplan", activityType: .kraft)
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

    @Test func finishSessionSetsEndDateAndPersists() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let viewModel = WorkoutSessionViewModel.start(context: context, plan: nil, activityType: .laufen)
        viewModel.updateAverageHeartRate(140)

        await viewModel.finishSession()

        #expect(viewModel.session.endDate != nil)
        #expect(try context.fetchCount(FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.endDate == nil })) == 0)
    }

    @Test func discardSessionDeletesSession() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let viewModel = WorkoutSessionViewModel.start(context: context, plan: nil, activityType: .laufen)
        await viewModel.discardSession()

        #expect(try context.fetchCount(FetchDescriptor<WorkoutSession>()) == 0)
    }

    @Test func exerciseSectionsFollowPlanOrderWhenPlanExists() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let exerciseA = Exercise(name: "A")
        let exerciseB = Exercise(name: "B")
        context.insert(exerciseA)
        context.insert(exerciseB)
        let plan = Workout(name: "Testplan", activityType: .kraft)
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

    @Test func firstIncompleteExerciseNameReturnsFirstExerciseWithOpenSet() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let exerciseA = Exercise(name: "A")
        let exerciseB = Exercise(name: "B")
        context.insert(exerciseA)
        context.insert(exerciseB)

        let viewModel = WorkoutSessionViewModel.start(context: context, plan: nil, activityType: .kraft)
        viewModel.addSet(for: exerciseA)
        viewModel.addSet(for: exerciseB)

        #expect(viewModel.firstIncompleteExerciseName == "A")
    }

    @Test func firstIncompleteExerciseNameSkipsCompletedExercises() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let exerciseA = Exercise(name: "A")
        let exerciseB = Exercise(name: "B")
        context.insert(exerciseA)
        context.insert(exerciseB)

        let viewModel = WorkoutSessionViewModel.start(context: context, plan: nil, activityType: .kraft)
        viewModel.addSet(for: exerciseA)
        viewModel.addSet(for: exerciseB)
        viewModel.toggleSetCompletion(viewModel.session.setLogs.first { $0.exerciseName == "A" }!)

        #expect(viewModel.firstIncompleteExerciseName == "B")
    }

    @Test func firstIncompleteExerciseNameFallsBackToLastWhenAllComplete() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let exerciseA = Exercise(name: "A")
        let exerciseB = Exercise(name: "B")
        context.insert(exerciseA)
        context.insert(exerciseB)

        let viewModel = WorkoutSessionViewModel.start(context: context, plan: nil, activityType: .kraft)
        viewModel.addSet(for: exerciseA)
        viewModel.addSet(for: exerciseB)
        for setLog in viewModel.session.setLogs {
            viewModel.toggleSetCompletion(setLog)
        }

        #expect(viewModel.firstIncompleteExerciseName == "B")
    }

    @Test func isExerciseCompleteReflectsSetCompletionState() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Kniebeuge")
        context.insert(exercise)

        let viewModel = WorkoutSessionViewModel.start(context: context, plan: nil, activityType: .kraft)
        viewModel.addSet(for: exercise)
        viewModel.addSet(for: exercise)

        #expect(viewModel.isExerciseComplete("Kniebeuge") == false)

        for setLog in viewModel.session.setLogs {
            viewModel.toggleSetCompletion(setLog)
        }

        #expect(viewModel.isExerciseComplete("Kniebeuge") == true)
        #expect(viewModel.isExerciseComplete("Unbekannt") == false)
    }

    @Test func adjustRestDurationNeverTouchesStartDate() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Kniebeuge")
        context.insert(exercise)

        let viewModel = WorkoutSessionViewModel.start(context: context, plan: nil, activityType: .kraft)
        viewModel.addSet(for: exercise)
        viewModel.toggleSetCompletion(viewModel.session.setLogs[0])
        let startBefore = viewModel.restTimerStartDate

        viewModel.adjustRestDuration(by: 10)
        viewModel.adjustRestDuration(by: -10)

        #expect(viewModel.restTimerStartDate == startBefore)
    }

    @Test func adjustRestDurationRespectsFifteenSecondFloor() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let viewModel = WorkoutSessionViewModel.start(context: context, plan: nil, activityType: .kraft)
        viewModel.adjustRestDuration(by: -1000)

        #expect(viewModel.restTimerDuration == 15)
    }

    @Test func nextIncompleteSetIDReturnsFirstOpenSet() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Kniebeuge")
        context.insert(exercise)

        let viewModel = WorkoutSessionViewModel.start(context: context, plan: nil, activityType: .kraft)
        viewModel.addSet(for: exercise)
        viewModel.addSet(for: exercise)
        let firstSet = viewModel.session.setLogs.sorted { $0.setIndex < $1.setIndex }[0]
        let secondSet = viewModel.session.setLogs.sorted { $0.setIndex < $1.setIndex }[1]

        #expect(viewModel.nextIncompleteSetID(in: "Kniebeuge") == firstSet.persistentModelID)

        viewModel.toggleSetCompletion(firstSet)

        #expect(viewModel.nextIncompleteSetID(in: "Kniebeuge") == secondSet.persistentModelID)
    }

    @Test func nextIncompleteSetIDReturnsNilWhenAllCompleteOrUnknownExercise() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Kniebeuge")
        context.insert(exercise)

        let viewModel = WorkoutSessionViewModel.start(context: context, plan: nil, activityType: .kraft)
        viewModel.addSet(for: exercise)
        viewModel.toggleSetCompletion(viewModel.session.setLogs[0])

        #expect(viewModel.nextIncompleteSetID(in: "Kniebeuge") == nil)
        #expect(viewModel.nextIncompleteSetID(in: "Unbekannt") == nil)
    }

    @Test func exerciseSectionsExposeTargetOnlyWhenPlanExists() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Kniebeuge")
        context.insert(exercise)
        let plan = Workout(name: "Testplan", activityType: .kraft)
        context.insert(plan)
        let plannedExercise = PlannedExercise(orderIndex: 0, exercise: exercise, targetSets: 3, targetReps: 8, targetWeightKg: 60)
        plannedExercise.plan = plan
        context.insert(plannedExercise)
        try context.save()

        let planViewModel = WorkoutSessionViewModel.start(context: context, plan: plan, activityType: .kraft)
        #expect(planViewModel.exerciseSections.first?.target?.exerciseName == "Kniebeuge")

        let freeViewModel = WorkoutSessionViewModel.start(context: context, plan: nil, activityType: .kraft)
        freeViewModel.addSet(for: exercise)
        #expect(freeViewModel.exerciseSections.first?.target == nil)
    }

    @Test func previousAttemptReturnsNilWithoutOtherCompletedSession() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Kniebeuge")
        context.insert(exercise)

        let viewModel = WorkoutSessionViewModel.start(context: context, plan: nil, activityType: .kraft)

        #expect(viewModel.previousAttempt(for: "Kniebeuge") == nil)
    }

    @Test func previousAttemptIgnoresOpenSessions() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Kniebeuge")
        context.insert(exercise)

        let openViewModel = WorkoutSessionViewModel.start(context: context, plan: nil, activityType: .kraft)
        openViewModel.addSet(for: exercise, suggestedReps: 8, suggestedWeightKg: 60)

        let currentViewModel = WorkoutSessionViewModel.start(context: context, plan: nil, activityType: .kraft)

        #expect(currentViewModel.previousAttempt(for: "Kniebeuge") == nil)
    }

    @Test func previousAttemptIgnoresNonMatchingExercise() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let exerciseA = Exercise(name: "A")
        context.insert(exerciseA)

        let pastViewModel = WorkoutSessionViewModel.start(context: context, plan: nil, activityType: .kraft, healthKitService: MockHealthKitService())
        pastViewModel.addSet(for: exerciseA, suggestedReps: 8, suggestedWeightKg: 60)
        await pastViewModel.finishSession()

        let currentViewModel = WorkoutSessionViewModel.start(context: context, plan: nil, activityType: .kraft, healthKitService: MockHealthKitService())

        #expect(currentViewModel.previousAttempt(for: "B") == nil)
    }

    @Test func previousAttemptFindsMostRecentMatchingCompletedSession() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Kniebeuge")
        context.insert(exercise)

        let olderViewModel = WorkoutSessionViewModel.start(context: context, plan: nil, activityType: .kraft, healthKitService: MockHealthKitService())
        olderViewModel.addSet(for: exercise, suggestedReps: 8, suggestedWeightKg: 50)
        olderViewModel.session.startDate = Date(timeIntervalSinceNow: -7200)
        await olderViewModel.finishSession()

        let newerViewModel = WorkoutSessionViewModel.start(context: context, plan: nil, activityType: .kraft, healthKitService: MockHealthKitService())
        newerViewModel.addSet(for: exercise, suggestedReps: 8, suggestedWeightKg: 60)
        newerViewModel.session.startDate = Date(timeIntervalSinceNow: -3600)
        await newerViewModel.finishSession()

        let currentViewModel = WorkoutSessionViewModel.start(context: context, plan: nil, activityType: .kraft, healthKitService: MockHealthKitService())

        let attempt = currentViewModel.previousAttempt(for: "Kniebeuge")
        #expect(attempt?.sets.first?.weightKg == 60)
    }

    @Test func previousAttemptExcludesCurrentSessionEvenIfMatching() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Kniebeuge")
        context.insert(exercise)

        // Die aktuelle Session ist selbst abgeschlossen und würde auf den
        // Fetch-Filter (endDate != nil, passende exerciseName) passen - muss
        // trotzdem über den id-Ausschluss ignoriert werden, sonst würde
        // previousAttempt sich mit sich selbst vergleichen.
        let viewModel = WorkoutSessionViewModel.start(context: context, plan: nil, activityType: .kraft, healthKitService: MockHealthKitService())
        viewModel.addSet(for: exercise, suggestedReps: 8, suggestedWeightKg: 60)
        viewModel.toggleSetCompletion(viewModel.session.setLogs[0])
        await viewModel.finishSession()

        #expect(viewModel.previousAttempt(for: "Kniebeuge") == nil)
    }

    @Test func startFromPlanSeedsSegmentLogsWithTargetValues() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let plan = Workout(name: "Radtour", activityType: .radfahren)
        context.insert(plan)
        let segment = PlannedSegment(orderIndex: 0, label: "Warmup", targetDistanceMeters: 5000, targetDurationSeconds: 600)
        segment.plan = plan
        context.insert(segment)
        try context.save()

        let viewModel = WorkoutSessionViewModel.start(context: context, plan: plan, activityType: .radfahren)

        #expect(viewModel.segmentSections.count == 1)
        #expect(viewModel.segmentSections[0].label == "Warmup")
        #expect(viewModel.segmentSections[0].distanceMeters == 5000)
        #expect(viewModel.segmentSections[0].durationSeconds == 600)
    }

    @Test func startWithoutPlanCreatesNoSegmentLogs() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let viewModel = WorkoutSessionViewModel.start(context: context, plan: nil, activityType: .radfahren)

        #expect(viewModel.segmentSections.isEmpty)
    }

    @Test func addSegmentAppendsAdHocSegmentInOrder() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let viewModel = WorkoutSessionViewModel.start(context: context, plan: nil, activityType: .radfahren)
        viewModel.addSegment(label: "Segment 1")
        viewModel.addSegment(label: "Segment 2")

        #expect(viewModel.segmentSections.map(\.label) == ["Segment 1", "Segment 2"])
    }

    @Test func toggleSegmentCompletionTogglesState() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let viewModel = WorkoutSessionViewModel.start(context: context, plan: nil, activityType: .radfahren)
        viewModel.addSegment(label: "Sprint")
        let segmentLog = viewModel.segmentSections[0]

        #expect(segmentLog.isCompleted == false)
        viewModel.toggleSegmentCompletion(segmentLog)
        #expect(segmentLog.isCompleted == true)
    }

    @Test func totalDistanceMetersSumsSegmentLogsAndNilWhenEmpty() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let viewModel = WorkoutSessionViewModel.start(context: context, plan: nil, activityType: .radfahren)
        #expect(viewModel.session.totalDistanceMeters == nil)

        viewModel.addSegment(label: "Warmup")
        viewModel.addSegment(label: "Sprint")
        viewModel.updateSegment(viewModel.segmentSections[0], distanceMeters: 2000, durationSeconds: nil)
        viewModel.updateSegment(viewModel.segmentSections[1], distanceMeters: 3000, durationSeconds: nil)

        #expect(viewModel.session.totalDistanceMeters == 5000)
    }
}
