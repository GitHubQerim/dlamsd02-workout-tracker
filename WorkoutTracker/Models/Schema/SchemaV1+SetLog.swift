import SwiftData

@Model
final class SetLog {
    var setIndex: Int
    var reps: Int
    var weightKg: Double
    var isCompleted: Bool

    /// Denormalisierter Namens-Snapshot - bleibt lesbar, falls
    /// `exercise` später via .nullify auf nil gesetzt wird.
    var exerciseName: String

    @Relationship(deleteRule: .nullify)
    var exercise: Exercise?

    var session: WorkoutSession?

    init(setIndex: Int, exercise: Exercise, reps: Int, weightKg: Double, isCompleted: Bool = false) {
        self.setIndex = setIndex
        self.exercise = exercise
        self.exerciseName = exercise.name
        self.reps = reps
        self.weightKg = weightKg
        self.isCompleted = isCompleted
    }
}
