import Foundation
import SwiftData

@Model
final class Workout {
    var name: String
    var activityType: ActivityType
    var createdAt: Date

    // .cascade: eine PlannedExercise-Zeile hat außerhalb ihres Plans
    // keine Bedeutung. Nur bei Kraft-Workouts befüllt (siehe ADR 0009).
    @Relationship(deleteRule: .cascade, inverse: \PlannedExercise.plan)
    var plannedExercises: [PlannedExercise] = []

    // .cascade: ein Segment hat außerhalb seines Plans keine Bedeutung.
    // Nur bei Cardio-Workouts befüllt - Kraft und Cardio nutzen bewusst
    // getrennte Listen statt geteilter nilable Felder (ADR 0009).
    @Relationship(deleteRule: .cascade, inverse: \PlannedSegment.plan)
    var segments: [PlannedSegment] = []

    // .nullify: Löschen einer Vorlage darf niemals bereits protokollierte
    // WorkoutSessions löschen. Sessions werden stattdessen "planlos"
    // (plan == nil) - genau der Zustand, den freies Training ohnehin
    // unterstützen muss.
    @Relationship(deleteRule: .nullify, inverse: \WorkoutSession.plan)
    var sessions: [WorkoutSession] = []

    init(name: String, activityType: ActivityType = .kraft, createdAt: Date = .now) {
        self.name = name
        self.activityType = activityType
        self.createdAt = createdAt
    }
}
