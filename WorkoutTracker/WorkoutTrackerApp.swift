import SwiftUI
import SwiftData

@main
struct WorkoutTrackerApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(
                for: Schema(versionedSchema: SchemaV1.self),
                migrationPlan: WorkoutTrackerMigrationPlan.self
            )
        } catch {
            fatalError("ModelContainer konnte nicht erstellt werden: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    await ExerciseSeeder.seedIfNeeded(in: modelContainer.mainContext)
                    await ChallengeSeeder.seedIfNeeded(in: modelContainer.mainContext)
                    WidgetSnapshotRefresher.refresh(context: modelContainer.mainContext)
                }
        }
        .modelContainer(modelContainer)
    }
}
