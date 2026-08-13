import SwiftData

enum WorkoutTrackerMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [
            // Additiv, defaulted (`isWarmup = false`) - für jeden
            // Bestandsdatensatz semantisch korrekt (alle bisherigen Sätze
            // sind Arbeitssätze), daher reicht Lightweight-Migration.
            .lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self),
        ]
    }
}
