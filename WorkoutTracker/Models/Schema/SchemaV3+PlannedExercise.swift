import SwiftData
import Foundation

/// Aktuelle Form von `PlannedExercise` (siehe `CurrentSchema.swift`) - fügt
/// gegenüber `SchemaV1.PlannedExercise` das Feld `supersetGroupID` hinzu.
extension SchemaV3 {
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

        /// Gruppen-UUID statt direktem `partner`-Pointer - zwei
        /// `PlannedExercise`-Zeilen mit derselben nicht-nil UUID sind
        /// Superset-Partner. Erweitert sich sauber auf künftige Tri-/
        /// Giant-Sets (N Mitglieder teilen eine UUID), ohne bidirektionale
        /// Pointer-Pflege bei jedem Re-Link. `nil` = nicht verknüpft.
        var supersetGroupID: UUID?

        init(
            orderIndex: Int,
            exercise: Exercise,
            targetSets: Int? = nil,
            targetReps: Int? = nil,
            targetWeightKg: Double? = nil,
            supersetGroupID: UUID? = nil
        ) {
            self.orderIndex = orderIndex
            self.exercise = exercise
            self.exerciseName = exercise.name
            self.targetSets = targetSets
            self.targetReps = targetReps
            self.targetWeightKg = targetWeightKg
            self.supersetGroupID = supersetGroupID
        }
    }
}
