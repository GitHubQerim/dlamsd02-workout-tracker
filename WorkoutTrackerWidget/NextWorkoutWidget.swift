import WidgetKit
import SwiftUI

struct NextWorkoutEntry: TimelineEntry {
    let date: Date
    let snapshot: NextWorkoutSnapshot?
    let heatmapDays: [DayCount]
}

/// Die "nächstes Workout"-Info selbst ändert sich nur bei App-Start/Session-
/// Ende (`WidgetSnapshotRefresher` ruft danach `WidgetCenter.reloadAllTimelines()`),
/// die Mini-Heatmap teilt sich aber denselben `HeatmapSnapshot` wie
/// `HeatmapWidget` - deshalb hier dieselbe `.after(nextMidnight)`-Policy statt
/// `.never`, sonst hinkt die Mini-Heatmap nach einem App-losen Tag genauso
/// hinterher (siehe `DayCount.extendedToToday()`).
struct NextWorkoutTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextWorkoutEntry {
        NextWorkoutEntry(
            date: .now,
            snapshot: NextWorkoutSnapshot(programName: "Mein Programm", dayLabel: "Day 1", workoutName: "Push"),
            heatmapDays: DayCount.demoDays(count: 21)
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (NextWorkoutEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextWorkoutEntry>) -> Void) {
        completion(Timeline(entries: [currentEntry()], policy: .after(Self.nextRefreshDate())))
    }

    private func currentEntry() -> NextWorkoutEntry {
        let snapshot = WidgetSnapshotStore.read(NextWorkoutSnapshot.self, filename: NextWorkoutSnapshot.filename)
        let heatmap = WidgetSnapshotStore.read(HeatmapSnapshot.self, filename: HeatmapSnapshot.filename)
        return NextWorkoutEntry(date: .now, snapshot: snapshot, heatmapDays: (heatmap?.days ?? []).extendedToToday())
    }

    private static func nextRefreshDate(calendar: Calendar = .current) -> Date {
        calendar.nextDate(after: .now, matching: DateComponents(hour: 0, minute: 5), matchingPolicy: .nextTime)
            ?? Date.now.addingTimeInterval(86_400)
    }
}

struct NextWorkoutWidgetView: View {
    let entry: NextWorkoutEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Nächstes Workout")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let snapshot = entry.snapshot {
                    Text(snapshot.dayLabel)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(snapshot.workoutName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Kein Programm aktiv")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // Mini-Heatmap nur bei .systemMedium - in .systemSmall ist neben
            // dem Text schlicht kein Platz dafür. Füllt über
            // `AdaptiveHeatmapGrid` den kompletten verbleibenden Platz
            // (Breite UND Höhe) statt einer fest dimensionierten, zu kleinen
            // Ecke (Nutzer-Feedback nach echtem Gerätetest).
            if family == .systemMedium, !entry.heatmapDays.isEmpty {
                AdaptiveHeatmapGrid(days: entry.heatmapDays, cellSpacing: 2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) { DSColor.surfaceBase }
    }
}

struct NextWorkoutWidget: Widget {
    let kind = "NextWorkoutWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextWorkoutTimelineProvider()) { entry in
            NextWorkoutWidgetView(entry: entry)
        }
        .configurationDisplayName("Nächstes Workout")
        .description("Zeigt dein nächstes geplantes Workout aus dem Standard-Programm, bei mittlerer Größe inkl. Mini-Heatmap.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
