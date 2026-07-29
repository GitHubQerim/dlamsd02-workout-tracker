import Testing
import Foundation
@testable import WorkoutTracker

struct CompactSetDescriptionTests {
    @Test func formatsWholeNumberWeightWithoutDecimal() {
        let state = WorkoutSessionActivityAttributes.ContentState(
            workoutName: "Push",
            currentExerciseName: "Bankdrücken",
            currentSetNumber: 3,
            currentSetReps: 12,
            currentSetWeight: 40,
            currentExerciseSetCompletionFlags: [true, true, false],
            restTimerStartDate: nil,
            restTimerDuration: nil
        )

        #expect(state.compactSetDescription == "3x12 · 40kg")
    }

    @Test func formatsFractionalWeightWithOneDecimal() {
        let state = WorkoutSessionActivityAttributes.ContentState(
            workoutName: "Push",
            currentExerciseName: "Bankdrücken",
            currentSetNumber: 1,
            currentSetReps: 8,
            currentSetWeight: 42.5,
            currentExerciseSetCompletionFlags: [false],
            restTimerStartDate: nil,
            restTimerDuration: nil
        )

        // Locale-agnostig geprüft (System-Locale kann "42.5" oder "42,5"
        // liefern, siehe deutsches Komma an anderer Stelle im Projekt) -
        // dieselbe `.formatted(.number...)`-Formatierung wie in
        // RecentPersonalRecordsList.swift/PreviousSessionComparisonCard.swift.
        let expectedWeight = 42.5.formatted(.number.precision(.fractionLength(0...1)))
        #expect(state.compactSetDescription == "1x8 · \(expectedWeight)kg")
    }

    @Test func returnsNilWhenAnyComponentMissing() {
        let state = WorkoutSessionActivityAttributes.ContentState(
            workoutName: "Push",
            currentExerciseName: nil,
            currentSetNumber: nil,
            currentSetReps: nil,
            currentSetWeight: nil,
            currentExerciseSetCompletionFlags: [],
            restTimerStartDate: nil,
            restTimerDuration: nil
        )

        #expect(state.compactSetDescription == nil)
    }
}

@MainActor
struct LiveActivityContentStateProjectionTests {
    @Test func projectsActiveExerciseSetCompletionFlagsInOrder() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let exerciseA = Exercise(name: "Kniebeuge")
        let exerciseB = Exercise(name: "Bankdrücken")
        context.insert(exerciseA)
        context.insert(exerciseB)

        let viewModel = WorkoutSessionViewModel.start(context: context, plan: nil, activityType: .kraft, healthKitService: MockHealthKitService())
        viewModel.addSet(for: exerciseA, suggestedReps: 8, suggestedWeightKg: 60)
        viewModel.toggleSetCompletion(viewModel.session.setLogs[0])
        viewModel.addSet(for: exerciseB, suggestedReps: 12, suggestedWeightKg: 40)
        viewModel.addSet(for: exerciseB, suggestedReps: 12, suggestedWeightKg: 40)
        viewModel.toggleSetCompletion(viewModel.session.setLogs.first { $0.exerciseName == "Bankdrücken" && $0.setIndex == 0 }!)

        let state = viewModel.liveActivityContentState

        #expect(state.currentExerciseName == "Bankdrücken")
        #expect(state.currentExerciseSetCompletionFlags == [true, false])
        #expect(state.currentSetNumber == 2)
        #expect(state.currentSetReps == 12)
        #expect(state.currentSetWeight == 40)
    }

    @Test func projectsRestTimerOnlyWhileRunning() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Kniebeuge")
        context.insert(exercise)

        let viewModel = WorkoutSessionViewModel.start(context: context, plan: nil, activityType: .kraft, healthKitService: MockHealthKitService())
        viewModel.addSet(for: exercise, suggestedReps: 8, suggestedWeightKg: 60)

        #expect(viewModel.liveActivityContentState.restTimerStartDate == nil)
        #expect(viewModel.liveActivityContentState.restTimerDuration == nil)

        viewModel.toggleSetCompletion(viewModel.session.setLogs[0])

        #expect(viewModel.liveActivityContentState.restTimerStartDate != nil)
        #expect(viewModel.liveActivityContentState.restTimerDuration == viewModel.restTimerDuration)
    }
}
