import SwiftData

/// Dritte Schema-Version - fügt `PlannedExercise.supersetGroupID` hinzu
/// (Superset-Verknüpfung, siehe `SchemaV3+PlannedExercise.swift`). Alle
/// anderen Typen bleiben unverändert; `SetLog` bleibt bewusst bare (fällt
/// über die globale Typealias korrekt auf `SchemaV2.SetLog` zurück, da sich
/// dessen Form seit V2 nicht ändert).
enum SchemaV3: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(3, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            Exercise.self,
            Workout.self,
            PlannedExercise.self,
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
