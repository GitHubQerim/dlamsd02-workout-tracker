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

/// Festes, nicht scrollbares Fenster der letzten Wochen, die in die
/// verfügbare Breite passen (per `GeometryReader` ermittelt, statt einer
/// festen Spaltenzahl - sonst bleibt bei breiteren Widget-Familien
/// ungenutzter Leerraum rechts). WidgetKit unterstützt kein Scrollen, anders
/// als die App-eigene `ContributionHeatmapView`. Spalten-Gruppierung (7
/// aufeinanderfolgende Tage pro Spalte, unabhängig vom Wochentag) entspricht
/// demselben Prinzip wie dort (`LazyHGrid` mit 7 Zeilen), keine neue
/// Layout-Logik.
struct HeatmapWidgetView: View {
    let days: [DayCount]

    private let cellSize: CGFloat = 10
    private let cellSpacing: CGFloat = 3

    private func columnsOfDays(fittingWidth width: CGFloat) -> [[DayCount]] {
        let columnStride = cellSize + cellSpacing
        let columnCount = max(1, Int((width + cellSpacing) / columnStride))
        let recentDays = Array(days.suffix(columnCount * 7))
        return stride(from: 0, to: recentDays.count, by: 7).map {
            Array(recentDays[$0..<min($0 + 7, recentDays.count)])
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Trainings-Heatmap")
                .font(.caption)
                .foregroundStyle(.secondary)
            GeometryReader { geometry in
                let columns = columnsOfDays(fittingWidth: geometry.size.width)
                HStack(alignment: .top, spacing: cellSpacing) {
                    ForEach(columns.indices, id: \.self) { columnIndex in
                        VStack(spacing: cellSpacing) {
                            ForEach(columns[columnIndex]) { day in
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(HeatmapColorMapping.color(for: day.count))
                                    .frame(width: cellSize, height: cellSize)
                            }
                        }
                    }
                }
            }
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
