import SwiftData

enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            Exercise.self,
            WorkoutPlan.self,
            PlannedExercise.self,
            WorkoutSession.self,
            SetLog.self,
            Challenge.self,
            ChallengeEnrollment.self,
            ChallengeProgressEntry.self,
        ]
    }
}
