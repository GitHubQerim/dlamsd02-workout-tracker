import WidgetKit
import SwiftUI

struct NextWorkoutEntry: TimelineEntry {
    let date: Date
    let snapshot: NextWorkoutSnapshot?
    let heatmapDays: [DayCount]
}

/// `.never`-Reload-Policy: die Timeline aktualisiert sich nicht periodisch,
/// sondern nur wenn die App explizit `WidgetCenter.reloadTimelines(ofKind:)`
/// aufruft (`WidgetSnapshotRefresher`) - der Snapshot wird nie "von selbst"
/// veraltet nachgeladen, sondern nur bei tatsächlich relevanten Änderungen.
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
        completion(Timeline(entries: [currentEntry()], policy: .never))
    }

    private func currentEntry() -> NextWorkoutEntry {
        let snapshot = WidgetSnapshotStore.read(NextWorkoutSnapshot.self, filename: NextWorkoutSnapshot.filename)
        let heatmap = WidgetSnapshotStore.read(HeatmapSnapshot.self, filename: HeatmapSnapshot.filename)
        return NextWorkoutEntry(date: .now, snapshot: snapshot, heatmapDays: heatmap?.days ?? [])
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
            // dem Text schlicht kein Platz dafür (Nutzer-Vorgabe: nutzt den
            // sonst leeren Bereich rechts statt eines zweiten, separaten
            // Heatmap-Widgets zu brauchen).
            if family == .systemMedium, !entry.heatmapDays.isEmpty {
                Spacer(minLength: 8)
                MiniHeatmap(days: entry.heatmapDays)
            } else {
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) { DSColor.surfaceBase }
    }
}

/// Kompakte Heatmap-Vorschau (kleinere Zellen, weniger Wochen als das
/// eigenständige `HeatmapWidget`) - reine Platzausnutzung, kein Ersatz für
/// die große Heatmap-Ansicht.
private struct MiniHeatmap: View {
    let days: [DayCount]

    private let cellSize: CGFloat = 6
    private let cellSpacing: CGFloat = 2
    private let columnCount = 6

    private var columns: [[DayCount]] {
        let recentDays = Array(days.suffix(columnCount * 7))
        return stride(from: 0, to: recentDays.count, by: 7).map {
            Array(recentDays[$0..<min($0 + 7, recentDays.count)])
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: cellSpacing) {
            ForEach(columns.indices, id: \.self) { columnIndex in
                VStack(spacing: cellSpacing) {
                    ForEach(columns[columnIndex]) { day in
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(HeatmapColorMapping.color(for: day.count))
                            .frame(width: cellSize, height: cellSize)
                    }
                }
            }
        }
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
