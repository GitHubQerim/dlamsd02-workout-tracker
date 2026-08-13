import Testing
import SwiftData
import Foundation
@testable import WorkoutTracker

/// Erste echte Schema-Migration dieses Projekts (V1 -> V2, `SetLog.isWarmup`).
///
/// Bewusst KEIN Test, der `SchemaV1.SetLog` und `SchemaV2.SetLog` (= `SetLog`)
/// im selben Prozess tatsächlich instanziiert, um eine echte V1->V2-Migration
/// nachzustellen: beide Typen heißen intern identisch "SetLog" und teilen
/// sich dieselbe `@Relationship(inverse:)`-Bindung auf dem unveränderten,
/// geteilten `Exercise`-Typ - SwiftData wirft dabei einen harten,
/// nicht abfangbaren Fatal Error ("KeyPath relates to SetLog but I was asked
/// to cast it to SetLog"), sobald beide Typen im selben Prozess über diese
/// geteilte Relationship benutzt werden (verifiziert, reproduzierbar). Ein
/// solcher Test würde die komplette restliche Suite mit abschießen statt nur
/// selbst fehlzuschlagen. Das eigentliche V1->V2-Verhalten muss deshalb
/// manuell auf einem Gerät/Simulator mit echten Bestandsdaten verifiziert
/// werden (siehe PR-Beschreibung) - dieser Test deckt nur strukturell ab,
/// dass der Migrationsplan korrekt aufgebaut ist und ein frischer Store
/// unter dem aktuellen Schema klaglos funktioniert.
@MainActor
struct SchemaMigrationTests {
    @Test func migrationPlanDeclaresExactlyOneLightweightStageFromV1ToV2() throws {
        #expect(WorkoutTrackerMigrationPlan.schemas.count == 2)
        #expect(WorkoutTrackerMigrationPlan.stages.count == 1)
    }

    @Test func freshStoreOnCurrentSchemaOpensAndDefaultsIsWarmupToFalse() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("store")
        defer { try? FileManager.default.removeItem(at: storeURL) }

        let container = try ModelContainer(
            for: Schema(versionedSchema: SchemaV2.self),
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
}
