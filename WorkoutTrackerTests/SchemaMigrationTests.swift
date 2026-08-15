import Testing
import SwiftData
import Foundation
@testable import WorkoutTracker

/// Schema-Migrationen dieses Projekts (V1 -> V2 `SetLog.isWarmup`, V2 -> V3
/// `PlannedExercise.supersetGroupID`).
///
/// Bewusst KEIN Test, der zwei gleichnamige Versionen desselben Modelltyps
/// (z.B. `SchemaV1.SetLog` und `SchemaV2.SetLog` = `SetLog`) im selben
/// Prozess tatsächlich instanziiert, um eine echte Migration nachzustellen:
/// beide teilen sich dieselbe `@Relationship(inverse:)`-Bindung auf einem
/// unveränderten, geteilten Typ (z.B. `Exercise`) - SwiftData wirft dabei
/// einen harten, nicht abfangbaren Fatal Error ("KeyPath relates to X but I
/// was asked to cast it to X"), sobald beide Versionen im selben Prozess
/// über diese geteilte Relationship benutzt werden (verifiziert,
/// reproduzierbar). Ein solcher Test würde die komplette restliche Suite mit
/// abschießen statt nur selbst fehlzuschlagen. Das eigentliche Migrations-
/// verhalten muss deshalb manuell auf einem Gerät/Simulator mit echten
/// Bestandsdaten verifiziert werden (siehe PR-Beschreibung) - diese Tests
/// decken nur strukturell ab, dass der Migrationsplan korrekt aufgebaut ist
/// und ein frischer Store unter dem jeweiligen Schema klaglos funktioniert.
@MainActor
struct SchemaMigrationTests {
    @Test func migrationPlanDeclaresTwoLightweightStagesV1ToV3() throws {
        #expect(WorkoutTrackerMigrationPlan.schemas.count == 3)
        #expect(WorkoutTrackerMigrationPlan.stages.count == 2)
    }

    @Test func freshStoreOnCurrentSchemaOpensAndDefaultsIsWarmupToFalse() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("store")
        defer { try? FileManager.default.removeItem(at: storeURL) }

        let container = try ModelContainer(
            for: Schema(versionedSchema: SchemaV3.self),
            migrationPlan: WorkoutTrackerMigrationPlan.self,
            configurations: ModelConfiguration(url: storeURL)
        )
        let context = container.mainContext
        let exercise = Exercise(name: "Bankdrücken")
        context.insert(exercise)
        let setLog = SetLog(setIndex: 0, exercise: exercise, reps: 8, weightKg: 40)
        context.insert(setLog)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<SetLog>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.isWarmup == false)
    }

    @Test func freshStoreOnCurrentSchemaDefaultsSupersetGroupIDToNil() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("store")
        defer { try? FileManager.default.removeItem(at: storeURL) }

        let container = try ModelContainer(
            for: Schema(versionedSchema: SchemaV3.self),
            migrationPlan: WorkoutTrackerMigrationPlan.self,
            configurations: ModelConfiguration(url: storeURL)
        )
        let context = container.mainContext
        let exercise = Exercise(name: "Bankdrücken")
        context.insert(exercise)
        let plan = Workout(name: "Testplan", activityType: .kraft)
        context.insert(plan)
        let plannedExercise = PlannedExercise(orderIndex: 0, exercise: exercise)
        plannedExercise.plan = plan
        context.insert(plannedExercise)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<PlannedExercise>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.supersetGroupID == nil)
    }
}
