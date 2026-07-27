import SwiftData

@Model
final class Exercise {
    @Attribute(.unique) var name: String
    var muscleGroup: MuscleGroup?
    /// Kurzer Ausführungshinweis fürs künftige `icon-info`-Feature (Phase C).
    var executionHint: String?
    /// Unterscheidet Seed-Katalog von nutzerangelegten Übungen.
    var isCustom: Bool

    // .nullify statt .cascade: Löschen einer Katalog-Übung darf die
    // historischen SetLogs/PlannedExercises, die sie referenzieren,
    // nie mitreißen. Das `exerciseName`-Snapshot-Feld auf SetLog/
    // PlannedExercise hält die Historie auch nach dem Nullify lesbar.
    @Relationship(deleteRule: .nullify, inverse: \PlannedExercise.exercise)
    var plannedExercises: [PlannedExercise] = []

    @Relationship(deleteRule: .nullify, inverse: \SetLog.exercise)
    var setLogs: [SetLog] = []

    init(name: String, muscleGroup: MuscleGroup? = nil, executionHint: String? = nil, isCustom: Bool = false) {
        self.name = name
        self.muscleGroup = muscleGroup
        self.executionHint = executionHint
        self.isCustom = isCustom
    }
}
