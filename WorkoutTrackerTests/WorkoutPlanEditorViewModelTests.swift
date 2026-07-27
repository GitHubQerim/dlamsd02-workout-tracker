import Testing
import SwiftData
@testable import WorkoutTracker

@MainActor
struct WorkoutPlanEditorViewModelTests {
    @Test func loadsExistingDraftsSortedByOrderIndex() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let exerciseA = Exercise(name: "A")
        let exerciseB = Exercise(name: "B")
        context.insert(exerciseA)
        context.insert(exerciseB)

        let plan = WorkoutPlan(name: "Testplan", activityType: .kraft)
        context.insert(plan)

        let secondExercise = PlannedExercise(orderIndex: 1, exercise: exerciseB, targetSets: 3, targetReps: 8)
        secondExercise.plan = plan
        context.insert(secondExercise)
        let firstExercise = PlannedExercise(orderIndex: 0, exercise: exerciseA, targetSets: 4, targetReps: 10)
        firstExercise.plan = plan
        context.insert(firstExercise)

        try context.save()

        let viewModel = WorkoutPlanEditorViewModel(context: context, editing: plan)

        #expect(viewModel.drafts.map(\.exercise.name) == ["A", "B"])
    }

    @Test func updateActivityTypeClearsUnusedFields() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Kniebeuge")
        context.insert(exercise)

        let viewModel = WorkoutPlanEditorViewModel(context: context)
        viewModel.addExercise(exercise)
        viewModel.updateStrengthTargets(draftID: viewModel.drafts[0].id, sets: 3, reps: 10, weightKg: 60)

        viewModel.updateActivityType(.laufen)

        let draft = viewModel.drafts[0]
        #expect(draft.targetSets == nil)
        #expect(draft.targetReps == nil)
        #expect(draft.targetWeightKg == nil)
    }

    @Test func saveWithoutDraftsFailsWithValidationMessage() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let viewModel = WorkoutPlanEditorViewModel(context: context)
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

        let plan = WorkoutPlan(name: "Testplan", activityType: .kraft)
        context.insert(plan)
        let keptExercise = PlannedExercise(orderIndex: 0, exercise: exerciseA, targetSets: 3, targetReps: 10)
        keptExercise.plan = plan
        context.insert(keptExercise)
        let removedExercise = PlannedExercise(orderIndex: 1, exercise: exerciseB, targetSets: 3, targetReps: 10)
        removedExercise.plan = plan
        context.insert(removedExercise)
        try context.save()

        let viewModel = WorkoutPlanEditorViewModel(context: context, editing: plan)
        // exerciseB (index 1) entfernen, exerciseC neu hinzufügen.
        viewModel.removeDraft(id: viewModel.drafts[1].id)
        viewModel.addExercise(exerciseC)

        let saved = viewModel.save()

        #expect(saved == true)
        #expect(plan.plannedExercises.count == 2)
        #expect(Set(plan.plannedExercises.map(\.exerciseName)) == ["A", "C"])
        #expect(try context.fetchCount(FetchDescriptor<PlannedExercise>()) == 2)
    }
}
