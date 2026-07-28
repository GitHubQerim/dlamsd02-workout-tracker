import Foundation
import SwiftData

/// Ein benannter, geordneter Split aus mehreren `Workout`s (z.B. "Arnold
/// Split" = Day 1/Day 2/Leg Day). Trennt das "was mache ich an einem Tag"
/// (`Workout`) vom "in welcher Reihenfolge über mehrere Tage" (`WorkoutProgram`),
/// damit man Workouts unabhängig anlegen und erst später verbinden kann.
@Model
final class WorkoutProgram {
    var name: String
    var isDefault: Bool
    var createdAt: Date

    // .cascade: ein WorkoutProgramEntry hat außerhalb seines Programms keine
    // Bedeutung.
    @Relationship(deleteRule: .cascade, inverse: \WorkoutProgramEntry.program)
    var entries: [WorkoutProgramEntry] = []

    init(name: String, isDefault: Bool = false, createdAt: Date = .now) {
        self.name = name
        self.isDefault = isDefault
        self.createdAt = createdAt
    }
}

/// Ein Tag innerhalb eines `WorkoutProgram` (z.B. "Day 1" -> Push-Workout).
@Model
final class WorkoutProgramEntry {
    /// Eigene ID statt `persistentModelID` - wird als stabiler Schlüssel in
    /// `WorkoutSession.programEntryID` gespeichert, um "letzter Tag"/"nächster
    /// Tag" auch nach Umbenennung/Umsortierung zuverlässig zuzuordnen.
    @Attribute(.unique) var id: UUID
    var orderIndex: Int
    var dayLabel: String

    /// Denormalisierter Namens-Snapshot zum Anlagezeitpunkt - bleibt lesbar,
    /// falls `workout` später via .nullify auf nil gesetzt wird.
    var workoutName: String

    @Relationship(deleteRule: .nullify)
    var workout: Workout?

    var program: WorkoutProgram?

    init(id: UUID = UUID(), orderIndex: Int, dayLabel: String, workout: Workout) {
        self.id = id
        self.orderIndex = orderIndex
        self.dayLabel = dayLabel
        self.workout = workout
        self.workoutName = workout.name
    }
}
