import SwiftData

enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

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
