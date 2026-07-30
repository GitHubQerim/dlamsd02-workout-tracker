import WidgetKit
import SwiftUI

struct HeatmapEntry: TimelineEntry {
    let date: Date
    let days: [DayCount]
}

struct HeatmapTimelineProvider: TimelineProvider {
    /// Realistische Demo-Daten statt eines leeren Grids - sonst wirkt das
    /// Widget in der Galerie-Vorschau (vor dem ersten echten Snapshot) kaputt
    /// statt repräsentativ, anders als `NextWorkoutWidget`s Placeholder.
    func placeholder(in context: Context) -> HeatmapEntry {
        HeatmapEntry(date: .now, days: DayCount.demoDays(count: 70))
    }

    func getSnapshot(in context: Context, completion: @escaping (HeatmapEntry) -> Void) {
        completion(currentEntry())
    }

    /// Reload-Policy ist bewusst NICHT `.never`: der Snapshot-Inhalt selbst
    /// ändert sich zwar nur bei App-Start/Session-Ende, aber welcher Tag
    /// "heute" ist, ändert sich auch ohne neue Trainingsdaten - jede
    /// Mitternacht ist also eine "relevante Änderung", die WidgetKit von
    /// sich aus erneut anfragen muss, sonst bleibt die Anzeige nach einem
    /// App-losen Tag einen Tag hinter der Zeit zurück.
    func getTimeline(in context: Context, completion: @escaping (Timeline<HeatmapEntry>) -> Void) {
        completion(Timeline(entries: [currentEntry()], policy: .after(Self.nextRefreshDate())))
    }

    private func currentEntry() -> HeatmapEntry {
        let snapshot = WidgetSnapshotStore.read(HeatmapSnapshot.self, filename: HeatmapSnapshot.filename)
        return HeatmapEntry(date: .now, days: (snapshot?.days ?? []).extendedToToday())
    }

    private static func nextRefreshDate(calendar: Calendar = .current) -> Date {
        calendar.nextDate(after: .now, matching: DateComponents(hour: 0, minute: 5), matchingPolicy: .nextTime)
            ?? Date.now.addingTimeInterval(86_400)
    }
}

/// Festes, nicht scrollbares Fenster der letzten Wochen - `AdaptiveHeatmapGrid`
/// berechnet Zellengröße/Spaltenzahl so, dass die verfügbare Breite exakt
/// ausgefüllt wird, kein ungenutzter Leerraum rechts. WidgetKit unterstützt
/// kein Scrollen, anders als die App-eigene `ContributionHeatmapView`.
struct HeatmapWidgetView: View {
    let days: [DayCount]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Trainings-Heatmap")
                .font(.caption)
                .foregroundStyle(.secondary)
            AdaptiveHeatmapGrid(days: days)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) { DSColor.surfaceBase }
    }
}

struct HeatmapWidget: Widget {
    let kind = "HeatmapWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HeatmapTimelineProvider()) { entry in
            HeatmapWidgetView(days: entry.days)
        }
        .configurationDisplayName("Trainings-Heatmap")
        .description("Zeigt deine letzten Trainingstage.")
        .supportedFamilies([.systemMedium])
    }
}
