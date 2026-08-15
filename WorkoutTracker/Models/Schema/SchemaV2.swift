import SwiftData

/// Zweite Schema-Version - fügt `SetLog.isWarmup` hinzu (Warm-up-Sätze).
/// Alle anderen Model-Typen sind formgleich zu V1 und bleiben bewusst
/// simple Top-Level-Klassen (nicht pro Version genestet) - nur `SetLog`
/// selbst ändert sich, und keiner der anderen Typen hat eine gespeicherte
/// Relationship, deren Zieltyp sich ändert (siehe `CurrentSchema.swift`).
///
/// `PlannedExercise` ist HIER bewusst explizit als `SchemaV1.PlannedExercise`
/// qualifiziert statt bare - anders als die anderen unveränderten Typen
/// ändert sich `PlannedExercise` in `SchemaV3` (bekommt `supersetGroupID`).
/// Ein bare `PlannedExercise.self` würde ab dann über die globale
/// `CurrentSchema.swift`-Typealias auf die NEUE Form zeigen und diese
/// eingefrorene V2-Momentaufnahme rückwirkend verfälschen.
enum SchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            Exercise.self,
            Workout.self,
            SchemaV1.PlannedExercise.self,
            WorkoutSession.self,
            SetLog.self,
            Challenge.self,
            ChallengeEnrollment.self,
            ChallengeProgressEntry.self,
            WorkoutProgram.self,
            WorkoutProgramEntry.self,
            PlannedSegment.self,
            SegmentLog.self,
            PersonalRecord.self,
            RankState.self,
        ]
    }
}
