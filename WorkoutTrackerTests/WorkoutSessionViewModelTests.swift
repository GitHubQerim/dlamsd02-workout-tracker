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
        // Zweiter Satz, damit der erste getoggelte NICHT der letzte offene
        // Satz der Session ist - sonst würde der Timer laut
        // toggleSetCompletionOnLastSetDoesNotStartRestTimer nicht starten.
        viewModel.addSet(for: exercise, suggestedReps: 10, suggestedWeightKg: 50)
        viewModel.addSet(for: exercise, suggestedReps: 10, suggestedWeightKg: 50)
        let setLog = viewModel.session.setLogs[0]

        #expect(viewModel.isRestTimerRunning == false)
        viewModel.toggleSetCompletion(setLog)
        #expect(viewModel.isRestTimerRunning == true)
        #expect(setLog.isCompleted == true)
    }

    @Test func toggleSetCompletionOnLastSetDoesNotStartRestTimer() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Kniebeuge")
        context.insert(exercise)

        let viewModel = WorkoutSessionViewModel.start(context: context, plan: nil, activityType: .kraft)
        viewModel.addSet(for: exercise, suggestedReps: 10, suggestedWeightKg: 50)
        let setLog = viewModel.session.setLogs[0]

        viewModel.toggleSetCompletion(setLog)

        #expect(viewModel.isWorkoutComplete == true)
        #expect(viewModel.isRestTimerRunning == false)
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

    @Test func finishSessionEstimatesEnergyWhenBodyWeightAvailable() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Kniebeuge")
        context.insert(exercise)

        let mockHealthKitService = MockHealthKitService()
        mockHealthKitService.bodyWeightKgOverride = 80

        let viewModel = WorkoutSessionViewModel.start(context: context, plan: nil, activityType: .kraft, healthKitService: mockHealthKitService)
        viewModel.addSet(for: exercise, suggestedReps: 10, suggestedWeightKg: 50)
        viewModel.toggleSetCompletion(viewModel.session.setLogs[0])

        await viewModel.finishSession()

        #expect(mockHealthKitService.savedSessions.last?.activeEnergyKcal != nil)
    }

    @Test func finishSessionSkipsEnergyEstimateWhenBodyWeightUnavailable() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Kniebeuge")
        context.insert(exercise)

        let mockHealthKitService = MockHealthKitService()
        mockHealthKitService.bodyWeightKgOverride = nil

        let viewModel = WorkoutSessionViewModel.start(context: context, plan: nil, activityType: .kraft, healthKitService: mockHealthKitService)
        viewModel.addSet(for: exercise, suggestedReps: 10, suggestedWeightKg: 50)
        viewModel.toggleSetCompletion(viewModel.session.setLogs[0])

        await viewModel.finishSession()

        #expect(mockHealthKitService.savedSessions.last?.activeEnergyKcal == nil)
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
        // Zweiter Satz, damit der getoggelte nicht der letzte ist und der
        // Pausentimer tatsächlich startet (siehe
        // toggleSetCompletionOnLastSetDoesNotStartRestTimer).
        viewModel.addSet(for: exercise)
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

    @Test func finishSessionPopulatesLastRankReconciliation() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let viewModel = WorkoutSessionViewModel.start(context: context, plan: nil, activityType: .laufen, healthKitService: MockHealthKitService())
        #expect(viewModel.lastRankReconciliation == nil)

        await viewModel.finishSession()

        #expect(viewModel.lastRankReconciliation != nil)
    }

    // MARK: - Warm-up-Sätze

    @Test func addSetWithIsWarmupUsesIndependentSetIndexSequence() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Kniebeuge")
        context.insert(exercise)

        let viewModel = WorkoutSessionViewModel.start(context: context, plan: nil, activityType: .kraft)
        viewModel.addSet(for: exercise, isWarmup: true)
        viewModel.addSet(for: exercise, isWarmup: true)
        viewModel.addSet(for: exercise)

        let warmups = viewModel.session.setLogs.filter(\.isWarmup).sorted { $0.setIndex < $1.setIndex }
        let workSets = viewModel.session.setLogs.filter { !$0.isWarmup }

        #expect(warmups.map(\.setIndex) == [0, 1], "Warm-up-Zählung startet unabhängig bei 0")
        #expect(workSets.map(\.setIndex) == [0], "Ein hinzugefügter Warm-up-Satz darf die Arbeitssatz-Nummerierung nicht verschieben")
    }

    @Test func exerciseSectionSplitsWarmupAndWorkSets() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Kniebeuge")
        context.insert(exercise)

        let viewModel = WorkoutSessionViewModel.start(context: context, plan: nil, activityType: .kraft)
        viewModel.addSet(for: exercise, isWarmup: true)
        viewModel.addSet(for: exercise)
        viewModel.addSet(for: exercise)

        let section = viewModel.exerciseSections.first { $0.name == "Kniebeuge" }
        #expect(section?.warmupSets.count == 1)
        #expect(section?.workSets.count == 2)
        #expect(section?.sets.count == 3, "sets bleibt die kombinierte Liste")
    }

    @Test func toggleSetCompletionSkipsRestTimerForWarmupSet() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Kniebeuge")
        context.insert(exercise)

        let viewModel = WorkoutSessionViewModel.start(context: context, plan: nil, activityType: .kraft)
        // Zweiter (Arbeits-)Satz, damit isWorkoutComplete beim Warm-up-Toggle
        // nicht ohnehin schon true wäre - der Test soll gezielt die
        // Warm-up-Sonderregel prüfen, nicht die Session-Ende-Regel.
        viewModel.addSet(for: exercise, isWarmup: true)
        viewModel.addSet(for: exercise)
        let warmupSet = viewModel.session.setLogs.first { $0.isWarmup }!

        viewModel.toggleSetCompletion(warmupSet)

        #expect(warmupSet.isCompleted == true)
        #expect(viewModel.isRestTimerRunning == false, "Warm-up-Sätze pausieren nie")
    }

    @Test func isWorkoutCompleteIgnoresOpenWarmupSets() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Kniebeuge")
        context.insert(exercise)

        let viewModel = WorkoutSessionViewModel.start(context: context, plan: nil, activityType: .kraft)
        viewModel.addSet(for: exercise, isWarmup: true)
        viewModel.addSet(for: exercise)
        let workSet = viewModel.session.setLogs.first { !$0.isWarmup }!

        viewModel.toggleSetCompletion(workSet)

        #expect(viewModel.isWorkoutComplete == true, "Ein offener Warm-up-Satz darf den Session-Abschluss nicht blockieren")
    }

    @Test func isExerciseCompleteIgnoresOpenWarmupSets() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Kniebeuge")
        context.insert(exercise)

        let viewModel = WorkoutSessionViewModel.start(context: context, plan: nil, activityType: .kraft)
        viewModel.addSet(for: exercise, isWarmup: true)
        viewModel.addSet(for: exercise)
        let workSet = viewModel.session.setLogs.first { !$0.isWarmup }!

        viewModel.toggleSetCompletion(workSet)

        #expect(viewModel.isExerciseComplete("Kniebeuge") == true)
    }

    @Test func nextIncompleteSetIDIgnoresWarmupSets() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Kniebeuge")
        context.insert(exercise)

        let viewModel = WorkoutSessionViewModel.start(context: context, plan: nil, activityType: .kraft)
        viewModel.addSet(for: exercise, isWarmup: true)
        viewModel.addSet(for: exercise)
        let workSet = viewModel.session.setLogs.first { !$0.isWarmup }!

        #expect(viewModel.nextIncompleteSetID(in: "Kniebeuge") == workSet.persistentModelID)
    }

    @Test func previousAttemptExcludesWarmupSets() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Kniebeuge")
        context.insert(exercise)

        let pastViewModel = WorkoutSessionViewModel.start(context: context, plan: nil, activityType: .kraft, healthKitService: MockHealthKitService())
        pastViewModel.addSet(for: exercise, isWarmup: true, suggestedReps: 12, suggestedWeightKg: 20)
        pastViewModel.addSet(for: exercise, suggestedReps: 8, suggestedWeightKg: 60)
        await pastViewModel.finishSession()

        let currentViewModel = WorkoutSessionViewModel.start(context: context, plan: nil, activityType: .kraft, healthKitService: MockHealthKitService())

        let attempt = currentViewModel.previousAttempt(for: "Kniebeuge")
        #expect(attempt?.sets.count == 1, "Nur der Arbeitssatz darf im Vergleich auftauchen")
        #expect(attempt?.sets.first?.weightKg == 60)
    }

    // MARK: - Superset

    /// Baut eine geplante Session mit `count` Übungen (je `setsPerExercise`
    /// Sätzen, `orderIndex` in Aufrufreihenfolge) - gemeinsames Setup für
    /// die Superset-Tests, die alle mindestens zwei Übungen desselben Plans
    /// brauchen (`linkSuperset` funktioniert nur über `session.plan`).
    private func makePlannedSession(
        context: ModelContext,
        exerciseNames: [String],
        setsPerExercise: Int = 1
    ) -> WorkoutSessionViewModel {
        let plan = Workout(name: "Testplan", activityType: .kraft)
        context.insert(plan)
        for (index, name) in exerciseNames.enumerated() {
            let exercise = Exercise(name: name)
            context.insert(exercise)
            let plannedExercise = PlannedExercise(orderIndex: index, exercise: exercise, targetSets: setsPerExercise, targetReps: 8, targetWeightKg: 40)
            plannedExercise.plan = plan
            context.insert(plannedExercise)
        }
        try? context.save()
        return WorkoutSessionViewModel.start(context: context, plan: plan, activityType: .kraft)
    }

    @Test func linkSupersetSetsMatchingGroupIDOnBothPlannedExercises() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let viewModel = makePlannedSession(context: context, exerciseNames: ["A", "B"])

        viewModel.linkSuperset(attachedExerciseName: "B", toPrimaryExerciseName: "A")

        let plannedA = viewModel.session.plan!.plannedExercises.first { $0.exerciseName == "A" }!
        let plannedB = viewModel.session.plan!.plannedExercises.first { $0.exerciseName == "B" }!
        #expect(plannedA.supersetGroupID != nil)
        #expect(plannedA.supersetGroupID == plannedB.supersetGroupID)
    }

    @Test func linkSupersetReplacesPreviousPartnerWithoutOrphaningIt() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let viewModel = makePlannedSession(context: context, exerciseNames: ["A", "B", "C"])
        viewModel.linkSuperset(attachedExerciseName: "B", toPrimaryExerciseName: "A")

        viewModel.linkSuperset(attachedExerciseName: "C", toPrimaryExerciseName: "A")

        let plan = viewModel.session.plan!
        let plannedA = plan.plannedExercises.first { $0.exerciseName == "A" }!
        let plannedB = plan.plannedExercises.first { $0.exerciseName == "B" }!
        let plannedC = plan.plannedExercises.first { $0.exerciseName == "C" }!
        #expect(plannedB.supersetGroupID == nil, "Alte Partnerin darf nicht mit einer verwaisten Gruppen-ID zurückbleiben")
        #expect(plannedA.supersetGroupID != nil)
        #expect(plannedA.supersetGroupID == plannedC.supersetGroupID)
    }

    @Test func unlinkSupersetClearsGroupIDOnBothSidesEvenThoughOnlyOneWasTargeted() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let viewModel = makePlannedSession(context: context, exerciseNames: ["A", "B"])
        viewModel.linkSuperset(attachedExerciseName: "B", toPrimaryExerciseName: "A")

        viewModel.unlinkSuperset(exerciseName: "A")

        let plan = viewModel.session.plan!
        let plannedA = plan.plannedExercises.first { $0.exerciseName == "A" }!
        let plannedB = plan.plannedExercises.first { $0.exerciseName == "B" }!
        #expect(plannedA.supersetGroupID == nil)
        #expect(plannedB.supersetGroupID == nil, "Eine Gruppe mit nur einem verbleibenden Mitglied ist kein Superset mehr")
    }

    @Test func sessionRowsGroupsLinkedExercisesIntoSupersetRow() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let viewModel = makePlannedSession(context: context, exerciseNames: ["A", "B", "C"])

        viewModel.linkSuperset(attachedExerciseName: "B", toPrimaryExerciseName: "A")

        let rows = viewModel.sessionRows
        #expect(rows.count == 2, "A+B verschmelzen zu einer Zeile, C bleibt eigenständig")
        guard case .superset(let primary, let attached) = rows.first(where: { $0.id == "A" }) else {
            Issue.record("Erwartete .superset-Zeile für A wurde nicht gefunden")
            return
        }
        #expect(primary.name == "A")
        #expect(attached.name == "B")
        guard case .single(let soloSection) = rows.first(where: { $0.id == "C" }) else {
            Issue.record("Erwartete .single-Zeile für C wurde nicht gefunden")
            return
        }
        #expect(soloSection.name == "C")
    }

    @Test func toggleSetCompletionWaitsForSupersetPartnerBeforeStartingRestTimer() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        // Dritte, unverknüpfte Übung mit offenem Satz - sonst wäre nach
        // A+B die GESAMTE Session fertig, und die bestehende "letzter
        // offener Satz -> kein Timer, direkt abschließen"-Regel würde
        // greifen statt der hier zu testenden Superset-Gating-Regel.
        let viewModel = makePlannedSession(context: context, exerciseNames: ["A", "B", "C"])
        viewModel.linkSuperset(attachedExerciseName: "B", toPrimaryExerciseName: "A")

        let setA = viewModel.session.setLogs.first { $0.exerciseName == "A" }!
        let setB = viewModel.session.setLogs.first { $0.exerciseName == "B" }!

        viewModel.toggleSetCompletion(setA)
        #expect(viewModel.isRestTimerRunning == false, "Wartet auf den Partner-Satz derselben Runde")

        viewModel.toggleSetCompletion(setB)
        #expect(viewModel.isRestTimerRunning == true, "Beide Hälften der Runde sind jetzt fertig")
    }

    @Test func toggleSetCompletionIgnoresMismatchedRoundWithoutPartner() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        // A hat 2 Sätze, B nur 1 - bewusst kein Schutz gegen ungleiche
        // Satzanzahl (siehe Feature-Plan), der überzählige Satz wartet
        // einfach nicht auf einen Partner.
        let plan = Workout(name: "Testplan", activityType: .kraft)
        context.insert(plan)
        let exerciseA = Exercise(name: "A")
        context.insert(exerciseA)
        let plannedA = PlannedExercise(orderIndex: 0, exercise: exerciseA, targetSets: 2, targetReps: 8, targetWeightKg: 40)
        plannedA.plan = plan
        context.insert(plannedA)
        let exerciseB = Exercise(name: "B")
        context.insert(exerciseB)
        let plannedB = PlannedExercise(orderIndex: 1, exercise: exerciseB, targetSets: 1, targetReps: 8, targetWeightKg: 40)
        plannedB.plan = plan
        context.insert(plannedB)
        // Dritte, unverknüpfte Übung mit offenem Satz - siehe Kommentar in
        // toggleSetCompletionWaitsForSupersetPartnerBeforeStartingRestTimer.
        let exerciseC = Exercise(name: "C")
        context.insert(exerciseC)
        let plannedC = PlannedExercise(orderIndex: 2, exercise: exerciseC, targetSets: 1, targetReps: 8, targetWeightKg: 40)
        plannedC.plan = plan
        context.insert(plannedC)
        try context.save()
        let viewModel = WorkoutSessionViewModel.start(context: context, plan: plan, activityType: .kraft)
        viewModel.linkSuperset(attachedExerciseName: "B", toPrimaryExerciseName: "A")

        let setsA = viewModel.session.setLogs.filter { $0.exerciseName == "A" }.sorted { $0.setIndex < $1.setIndex }
        let setB = viewModel.session.setLogs.first { $0.exerciseName == "B" }!

        viewModel.toggleSetCompletion(setsA[0])
        #expect(viewModel.isRestTimerRunning == false, "setIndex 0 hat noch einen offenen Partner in B")
        viewModel.toggleSetCompletion(setB)
        viewModel.skipRestTimer()

        viewModel.toggleSetCompletion(setsA[1])
        #expect(viewModel.isRestTimerRunning == true, "setIndex 1 hat keinen Partner in B mehr - normale Pause statt endlosem Warten")
    }

    @Test func deleteSetRenumbersRemainingSetsOfSameKindContiguously() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Kniebeuge")
        context.insert(exercise)

        let viewModel = WorkoutSessionViewModel.start(context: context, plan: nil, activityType: .kraft)
        viewModel.addSet(for: exercise, suggestedReps: 8, suggestedWeightKg: 40) // setIndex 0
        viewModel.addSet(for: exercise, suggestedReps: 8, suggestedWeightKg: 50) // setIndex 1
        viewModel.addSet(for: exercise, suggestedReps: 8, suggestedWeightKg: 60) // setIndex 2
        let middleSet = viewModel.session.setLogs.first { $0.weightKg == 50 }!

        viewModel.deleteSet(middleSet)

        let remaining = viewModel.session.setLogs.sorted { $0.setIndex < $1.setIndex }
        #expect(remaining.map(\.setIndex) == [0, 1], "Nach dem Löschen müssen die verbleibenden Sätze lückenlos 0..n-1 sein")
        #expect(remaining.map(\.weightKg) == [40, 60])

        // Regressions-Check für den eigentlichen Bug, den die Nachnummerierung
        // verhindert: ohne sie würde ein neu hinzugefügter Satz denselben
        // setIndex wie ein Bestandssatz bekommen (existingCount == 2 träfe
        // sonst auf einen bereits vorhandenen setIndex 2).
        viewModel.addSet(for: exercise, suggestedReps: 8, suggestedWeightKg: 70)
        let allIndexes = viewModel.session.setLogs.map(\.setIndex).sorted()
        #expect(allIndexes == [0, 1, 2], "Kein doppelt vergebener setIndex nach Löschen + erneutem Hinzufügen")
    }

    @Test func deleteSetKeepsWarmupAndWorkSetNumberingIndependent() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Kniebeuge")
        context.insert(exercise)

        let viewModel = WorkoutSessionViewModel.start(context: context, plan: nil, activityType: .kraft)
        viewModel.addSet(for: exercise, isWarmup: true, suggestedReps: 12, suggestedWeightKg: 20)
        viewModel.addSet(for: exercise, suggestedReps: 8, suggestedWeightKg: 40)
        viewModel.addSet(for: exercise, suggestedReps: 8, suggestedWeightKg: 50)
        let workSetToDelete = viewModel.session.setLogs.first { !$0.isWarmup && $0.weightKg == 40 }!

        viewModel.deleteSet(workSetToDelete)

        let warmup = viewModel.session.setLogs.first { $0.isWarmup }
        #expect(warmup?.setIndex == 0, "Löschen eines Arbeitssatzes darf die Warm-up-Nummerierung nicht verschieben")
        let remainingWorkSet = viewModel.session.setLogs.first { !$0.isWarmup }
        #expect(remainingWorkSet?.setIndex == 0)
    }
}
