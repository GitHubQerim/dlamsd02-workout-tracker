import SwiftData
@testable import WorkoutTracker

// Wichtig (siehe ADR 0001, Nachtrag, und docs/journal.md für die volle
// Debugging-Geschichte): Ein `ModelContext` hält seinen `ModelContainer`
// nicht selbst am Leben. Wird aus einer Hilfsfunktion nur `container.mainContext`
// zurückgegeben, ohne dass der Aufrufer `container` selbst weiter referenziert,
// wird dieser dealloziert und der zurückgegebene Context zeigt auf einen
// bereits freigegebenen Store - der Crash tritt beim ersten `insert`/`save`
// auf. Deshalb hält jede Testfunktion ihren `container` explizit im eigenen
// Scope, nicht nur den daraus abgeleiteten Context.
@MainActor
func makeInMemoryContainer() throws -> ModelContainer {
    try ModelContainer(
        for: Schema(versionedSchema: SchemaV3.self),
        migrationPlan: WorkoutTrackerMigrationPlan.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
}
