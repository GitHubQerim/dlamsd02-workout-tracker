import Testing
@testable import WorkoutTracker

struct ProgressiveOverloadSuggestionTests {
    @Test func increasesWeightWhenTargetRepsReachedOrExceeded() {
        #expect(ProgressiveOverloadSuggestion.suggestedWeightKg(previousReps: 10, previousWeightKg: 50, targetReps: 10) == 52.5)
        #expect(ProgressiveOverloadSuggestion.suggestedWeightKg(previousReps: 12, previousWeightKg: 50, targetReps: 10) == 52.5)
    }

    @Test func keepsSameWeightWhenTargetRepsMissed() {
        #expect(ProgressiveOverloadSuggestion.suggestedWeightKg(previousReps: 8, previousWeightKg: 50, targetReps: 10) == 50)
    }
}
