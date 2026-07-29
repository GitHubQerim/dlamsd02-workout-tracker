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

    func getTimeline(in context: Context, completion: @escaping (Timeline<HeatmapEntry>) -> Void) {
        completion(Timeline(entries: [currentEntry()], policy: .never))
    }

    private func currentEntry() -> HeatmapEntry {
        let snapshot = WidgetSnapshotStore.read(HeatmapSnapshot.self, filename: HeatmapSnapshot.filename)
        return HeatmapEntry(date: .now, days: snapshot?.days ?? [])
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
