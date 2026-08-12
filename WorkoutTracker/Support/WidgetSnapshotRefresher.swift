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
    static func refresh(context: ModelContext, healthKitService: HealthKitServicing = HealthKitService()) {
        refreshNextWorkoutSnapshot(context: context)
        let days = refreshHeatmapSnapshot(context: context)
        WidgetCenter.shared.reloadAllTimelines()

        // Fire-and-forget statt refresh() selbst async zu machen (siehe ADR
        // 0015) - der HealthKit-Fetch soll den synchronen Snapshot-
        // Schreibvorgang nicht blockieren. ADR 0013 akzeptiert "kurzzeitig
        // veraltete" Widget-Daten bereits als Normalfall; ein zweites
        // Timeline-Reload, sobald der Move-Ring-Fetch durch ist, reicht.
        //
        // WICHTIG: der Task fasst `context` NICHT an (nur das bereits
        // synchron berechnete `days`) - ein `ModelContext` in einem
        // unstrukturierten `Task` festzuhalten, der die Laufzeit des
        // Aufrufers überlebt, ist exakt das in ADR 0001 dokumentierte
        // Bug-Muster (Context überlebt den Container nicht mehr).
        guard let since = days.first?.date else { return }
        let calendar = Calendar.current
        Task {
            guard let closedDates = try? await healthKitService.fetchClosedMoveRingDates(since: since, calendar: calendar) else { return }
            let mergedDays = ChallengeInsights.applyingMoveRingSignal(to: days, closedDates: closedDates, calendar: calendar)
            WidgetSnapshotStore.write(HeatmapSnapshot(days: mergedDays), filename: HeatmapSnapshot.filename)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private static func refreshNextWorkoutSnapshot(context: ModelContext) {
        let programDescriptor = FetchDescriptor<WorkoutProgram>(predicate: #Predicate { $0.isDefault == true })
        let sessionDescriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.endDate != nil })
        guard
            let program = try? context.fetch(programDescriptor).first,
            let completedSessions = try? context.fetch(sessionDescriptor),
            let nextEntry = program.nextEntry(among: completedSessions)
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

    @discardableResult
    private static func refreshHeatmapSnapshot(context: ModelContext) -> [DayCount] {
        let sessions = (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []
        let days = ChallengeInsights.heatmapDays(from: sessions)
        let snapshot = HeatmapSnapshot(days: days)
        WidgetSnapshotStore.write(snapshot, filename: HeatmapSnapshot.filename)
        return days
    }
}
