import Foundation
import SwiftData

@Model
final class SetLog {
    var setIndex: Int
    var reps: Int
    var weightKg: Double
    var isCompleted: Bool

    /// Anlagezeitpunkt - NICHT für die Satz-Nummerierung (dafür `setIndex`,
    /// der pro Übung bei 0 beginnt), sondern für die globale
    /// Erst-Auftrittsreihenfolge der Übungen im freien Training (siehe
    /// `WorkoutSessionViewModel.exerciseSections`): zwei SetLogs
    /// verschiedener Übungen können denselben `setIndex` haben (z.B. jeweils
    /// deren erster Satz), `createdAt` ist dagegen global eindeutig ordnend.
    var createdAt: Date

    /// Denormalisierter Namens-Snapshot - bleibt lesbar, falls
    /// `exercise` später via .nullify auf nil gesetzt wird.
    var exerciseName: String

    @Relationship(deleteRule: .nullify)
    var exercise: Exercise?

    var session: WorkoutSession?

    init(setIndex: Int, exercise: Exercise, reps: Int, weightKg: Double, isCompleted: Bool = false, createdAt: Date = .now) {
        self.setIndex = setIndex
        self.exercise = exercise
        self.exerciseName = exercise.name
        self.reps = reps
        self.weightKg = weightKg
        self.isCompleted = isCompleted
        self.createdAt = createdAt
    }
}
