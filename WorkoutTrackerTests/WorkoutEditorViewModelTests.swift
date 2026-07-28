import Testing
import SwiftData
@testable import WorkoutTracker

@MainActor
struct WorkoutEditorViewModelTests {
    @Test func loadsExistingDraftsSortedByOrderIndex() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let exerciseA = Exercise(name: "A")
        let exerciseB = Exercise(name: "B")
        context.insert(exerciseA)
        context.insert(exerciseB)

        let plan = Workout(name: "Testplan", activityType: .kraft)
        context.insert(plan)

        let secondExercise = PlannedExercise(orderIndex: 1, exercise: exerciseB, targetSets: 3, targetReps: 8)
        secondExercise.plan = plan
        context.insert(secondExercise)
        let firstExercise = PlannedExercise(orderIndex: 0, exercise: exerciseA, targetSets: 4, targetReps: 10)
        firstExercise.plan = plan
        context.insert(firstExercise)

        try context.save()

        let viewModel = WorkoutEditorViewModel(context: context, editing: plan)

        #expect(viewModel.drafts.map(\.exercise.name) == ["A", "B"])
    }

    /// Blocker-Fund aus dem architecture-reviewer-Pass (ADR 0009): Kraft und
    /// Cardio nutzen getrennte Listen (`drafts`/`segmentDrafts`) statt
    /// geteilter nilable Felder - `save()` muss deshalb bei jedem Speichern
    /// die gerade inaktive Seite komplett leeren, sonst blieben beim
    /// Umschalten eines bestehenden Plans tote Zeilen der alten Sportart in
    /// der DB hängen.
    @Test func switchingActivityTypeOnExistingPlanClearsInactiveSide() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Kniebeuge")
        context.insert(exercise)

        let plan = Workout(name: "Testplan", activityType: .kraft)
        context.insert(plan)
        let plannedExercise = PlannedExercise(orderIndex: 0, exercise: exercise, targetSets: 3, targetReps: 10)
        plannedExercise.plan = plan
        context.insert(plannedExercise)
        try context.save()

        let viewModel = WorkoutEditorViewModel(context: context, editing: plan)
        viewModel.updateActivityType(.radfahren)
        viewModel.addSegment()

        let saved = viewModel.save()

        #expect(saved == true)
        #expect(plan.plannedExercises.isEmpty)
        #expect(plan.segments.count == 1)
        #expect(try context.fetchCount(FetchDescriptor<PlannedExercise>()) == 0)
    }

    @Test func switchingActivityTypeBackToKraftClearsSegments() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let plan = Workout(name: "Testplan", activityType: .radfahren)
        context.insert(plan)
        let segment = PlannedSegment(orderIndex: 0, label: "Warmup", targetDistanceMeters: 5000)
        segment.plan = plan
        context.insert(segment)
        try context.save()

        let exercise = Exercise(name: "Kniebeuge")
        context.insert(exercise)

        let viewModel = WorkoutEditorViewModel(context: context, editing: plan)
        viewModel.updateActivityType(.kraft)
        viewModel.addExercise(exercise)

        let saved = viewModel.save()

        #expect(saved == true)
        #expect(plan.segments.isEmpty)
        #expect(plan.plannedExercises.count == 1)
        #expect(try context.fetchCount(FetchDescriptor<PlannedSegment>()) == 0)
    }

    @Test func saveWithoutDraftsFailsWithValidationMessage() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let viewModel = WorkoutEditorViewModel(context: context)
        viewModel.updateName("Leerer Plan")

        let saved = viewModel.save()

        #expect(saved == false)
        #expect(viewModel.validationMessage != nil)
    }

    @Test func saveCreatesUpdatesAndDeletesPlannedExercises() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let exerciseA = Exercise(name: "A")
        let exerciseB = Exercise(name: "B")
        let exerciseC = Exercise(name: "C")
        context.insert(exerciseA)
        context.insert(exerciseB)
        context.insert(exerciseC)

        let plan = Workout(name: "Testplan", activityType: .kraft)
        context.insert(plan)
        let keptExercise = PlannedExercise(orderIndex: 0, exercise: exerciseA, targetSets: 3, targetReps: 10)
        keptExercise.plan = plan
        context.insert(keptExercise)
        let removedExercise = PlannedExercise(orderIndex: 1, exercise: exerciseB, targetSets: 3, targetReps: 10)
        removedExercise.plan = plan
        context.insert(removedExercise)
        try context.save()

        let viewModel = WorkoutEditorViewModel(context: context, editing: plan)
        // exerciseB (index 1) entfernen, exerciseC neu hinzufügen.
        viewModel.removeDraft(id: viewModel.drafts[1].id)
        viewModel.addExercise(exerciseC)

        let saved = viewModel.save()

        #expect(saved == true)
        #expect(plan.plannedExercises.count == 2)
        #expect(Set(plan.plannedExercises.map(\.exerciseName)) == ["A", "C"])
        #expect(try context.fetchCount(FetchDescriptor<PlannedExercise>()) == 2)
    }

    @Test func addExerciseRejectsDuplicateNameInSamePlan() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Bankdrücken")
        context.insert(exercise)

        let viewModel = WorkoutEditorViewModel(context: context)
        let firstAdd = viewModel.addExercise(exercise)
        let secondAdd = viewModel.addExercise(exercise)

        #expect(firstAdd == true)
        #expect(secondAdd == false)
        #expect(viewModel.drafts.count == 1)
        #expect(viewModel.validationMessage != nil)
    }
}
