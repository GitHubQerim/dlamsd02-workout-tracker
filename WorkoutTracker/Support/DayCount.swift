import Foundation

/// Ein Tages-Aggregat (Session-Anzahl) für Heatmap/Wochenrückblick. Eigene
/// Datei statt in `ChallengeInsights.swift`, damit die Widget-Extension
/// (Heatmap-Widget, ADR 0013) diesen reinen Werttyp mitkompilieren kann, ohne
/// die SwiftData-Modelle mitzuziehen, die `ChallengeInsights`s Funktionen
/// brauchen. `Codable` für den Heatmap-Widget-Snapshot - `id` ist computed
/// aus `date`, wird von `Codable` also automatisch übergangen.
struct DayCount: Identifiable, Codable {
    let date: Date
    let count: Int
    var id: Date { date }
}

extension DayCount {
    /// Repräsentative Demo-Tage für Widget-Placeholder (Galerie-Vorschau vor
    /// dem ersten echten Snapshot) - von `HeatmapWidget` und
    /// `NextWorkoutWidget`s Mini-Heatmap gemeinsam genutzt statt zweier
    /// unabhängiger Kopien derselben Muster-Erzeugung.
    static func demoDays(count: Int) -> [DayCount] {
        let today = Calendar.current.startOfDay(for: .now)
        return (0..<count).reversed().compactMap { offset -> DayCount? in
            guard let date = Calendar.current.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DayCount(date: date, count: [0, 0, 1, 2, 3][offset % 5])
        }
    }
}
