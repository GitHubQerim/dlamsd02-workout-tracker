import Foundation
import SwiftData

@Model
final class WorkoutPlan {
    var name: String
    var createdAt: Date

    // .cascade: eine PlannedExercise-Zeile hat außerhalb ihres Plans
    // keine Bedeutung.
    @Relationship(deleteRule: .cascade, inverse: \PlannedExercise.plan)
    var plannedExercises: [PlannedExercise] = []

    // .nullify: Löschen einer Vorlage darf niemals bereits protokollierte
    // WorkoutSessions löschen. Sessions werden stattdessen "planlos"
    // (plan == nil) - genau der Zustand, den freies Training ohnehin
    // unterstützen muss.
    @Relationship(deleteRule: .nullify, inverse: \WorkoutSession.plan)
    var sessions: [WorkoutSession] = []

    init(name: String, createdAt: Date = .now) {
        self.name = name
        self.createdAt = createdAt
    }
}
