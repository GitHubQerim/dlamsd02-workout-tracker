import SwiftData

@Model
final class PlannedExercise {
    var orderIndex: Int

    // Rein Kraft - Cardio nutzt seit ADR 0009 ein eigenes Modell
    // (`PlannedSegment`) statt geteilter nilable Felder hier.
    var targetSets: Int?
    var targetReps: Int?
    var targetWeightKg: Double?

    /// Denormalisierter Namens-Snapshot zum Anlagezeitpunkt - bleibt
    /// lesbar, falls `exercise` später via .nullify auf nil gesetzt wird.
    var exerciseName: String

    @Relationship(deleteRule: .nullify)
    var exercise: Exercise?

    var plan: Workout?

    init(
        orderIndex: Int,
        exercise: Exercise,
        targetSets: Int? = nil,
        targetReps: Int? = nil,
        targetWeightKg: Double? = nil
    ) {
        self.orderIndex = orderIndex
        self.exercise = exercise
        self.exerciseName = exercise.name
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.targetWeightKg = targetWeightKg
    }
}
