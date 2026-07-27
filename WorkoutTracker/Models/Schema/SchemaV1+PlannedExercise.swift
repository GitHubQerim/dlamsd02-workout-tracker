import SwiftData

@Model
final class PlannedExercise {
    var orderIndex: Int

    // Kraft-Ziele (nil bei Cardio-Einträgen)
    var targetSets: Int?
    var targetReps: Int?
    var targetWeightKg: Double?
    // Cardio-Ziele (nil bei Kraft-Einträgen)
    var targetDistanceMeters: Double?
    var targetDurationSeconds: Double?

    /// Denormalisierter Namens-Snapshot zum Anlagezeitpunkt - bleibt
    /// lesbar, falls `exercise` später via .nullify auf nil gesetzt wird.
    var exerciseName: String

    @Relationship(deleteRule: .nullify)
    var exercise: Exercise?

    var plan: WorkoutPlan?

    init(
        orderIndex: Int,
        exercise: Exercise,
        targetSets: Int? = nil,
        targetReps: Int? = nil,
        targetWeightKg: Double? = nil,
        targetDistanceMeters: Double? = nil,
        targetDurationSeconds: Double? = nil
    ) {
        self.orderIndex = orderIndex
        self.exercise = exercise
        self.exerciseName = exercise.name
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.targetWeightKg = targetWeightKg
        self.targetDistanceMeters = targetDistanceMeters
        self.targetDurationSeconds = targetDurationSeconds
    }
}
