import Foundation
import SwiftData
import WidgetKit

/// Schreibt beide Widget-Snapshots neu und stößt ein Timeline-Reload an -
/// aufgerufen nach jedem Save, der die Widget-Anzeige beeinflussen könnte
/// (Session-Ende, App-Start). Nur im App-Target (braucht SwiftData + WidgetKit),
/// anders als `WidgetSnapshotStore`/die Snapshot-DTOs, die auch die Extension
/// zum Lesen braucht.
@MainActor
enum WidgetSnapshotRefresher {
    static func refresh(context: ModelContext) {
        refreshNextWorkoutSnapshot(context: context)
        refreshHeatmapSnapshot(context: context)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func refreshNextWorkoutSnapshot(context: ModelContext) {
        let descriptor = FetchDescriptor<WorkoutProgram>(predicate: #Predicate { $0.isDefault == true })
        guard
            let program = try? context.fetch(descriptor).first,
            let nextEntry = program.nextEntry(in: context)
        else {
            WidgetSnapshotStore.delete(filename: NextWorkoutSnapshot.filename)
            return
        }
        let snapshot = NextWorkoutSnapshot(
            programName: program.name,
            dayLabel: nextEntry.dayLabel,
            workoutName: nextEntry.workoutName
        )
        WidgetSnapshotStore.write(snapshot, filename: NextWorkoutSnapshot.filename)
    }

    private static func refreshHeatmapSnapshot(context: ModelContext) {
        let sessions = (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []
        let snapshot = HeatmapSnapshot(days: ChallengeInsights.heatmapDays(from: sessions))
        WidgetSnapshotStore.write(snapshot, filename: HeatmapSnapshot.filename)
    }
}
