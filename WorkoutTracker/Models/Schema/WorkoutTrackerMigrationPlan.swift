import SwiftData

enum WorkoutTrackerMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    static var stages: [MigrationStage] {
        [] // Noch keine Migration nötig - erste Schema-Version.
    }
}
