import SwiftUI

/// Füllt den ihr zugewiesenen Platz vollständig aus, statt einer festen
/// Zellengröße mit Restfläche rechts/unten - von `HeatmapWidget` (große,
/// eigenständige Ansicht) und `NextWorkoutWidget`s Mini-Heatmap (rechte
/// Hälfte) gemeinsam genutzt, statt zweier unabhängiger, fest
/// dimensionierter Kopien derselben Grid-Logik.
///
/// Zwei-Pass-Größenberechnung: Zellengröße erst aus der verfügbaren Höhe
/// ableiten (immer 7 Zeilen), damit passende Spaltenzahl ermitteln, dann die
/// Zellengröße anhand dieser Spaltenzahl aus der Breite neu berechnen - so
/// füllt das Grid die Breite exakt aus, statt eine Restspalte ungenutzt zu
/// lassen (das war der Bug: feste `cellSize` + `Int(...)`-Abrundung ließ
/// immer einen Rest übrig).
struct AdaptiveHeatmapGrid: View {
    let days: [DayCount]
    var cellSpacing: CGFloat = 3

    private static let rowCount = 7

    var body: some View {
        GeometryReader { geometry in
            let rows = CGFloat(Self.rowCount)
            let heightDrivenCellSize = max((geometry.size.height - (rows - 1) * cellSpacing) / rows, 2)
            let columnStride = heightDrivenCellSize + cellSpacing
            let columnCount = max(1, Int((geometry.size.width + cellSpacing) / columnStride))
            let cellSize = max((geometry.size.width - CGFloat(columnCount - 1) * cellSpacing) / CGFloat(columnCount), 2)

            let recentDays = Array(days.suffix(columnCount * Self.rowCount))
            let columns = stride(from: 0, to: recentDays.count, by: Self.rowCount).map {
                Array(recentDays[$0..<min($0 + Self.rowCount, recentDays.count)])
            }

            HStack(alignment: .top, spacing: cellSpacing) {
                ForEach(columns.indices, id: \.self) { columnIndex in
                    VStack(spacing: cellSpacing) {
                        ForEach(columns[columnIndex]) { day in
                            RoundedRectangle(cornerRadius: max(cellSize * 0.2, 1), style: .continuous)
                                .fill(HeatmapColorMapping.color(for: day.count))
                                .frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
