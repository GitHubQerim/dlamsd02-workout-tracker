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

extension Array where Element == DayCount {
    /// Verlängert eine vom Hauptapp-Prozess geschriebene Tages-Reihe bis zum
    /// tatsächlichen "heute" - der Widget-Snapshot wird nur bei App-Start/
    /// Session-Ende neu geschrieben (`WidgetSnapshotRefresher`), ohne das
    /// würde die Widget-Heatmap nach Mitternacht einen Tag hinter der Zeit
    /// hängen bleiben, bis die App das nächste Mal geöffnet wird. Fehlende
    /// Tage werden mit `count: 0` aufgefüllt (korrekt: kein Training an
    /// diesen Tagen bekannt).
    func extendedToToday(calendar: Calendar = .current, today: Date = .now) -> [DayCount] {
        guard var lastDate = last?.date else { return self }
        let todayStart = calendar.startOfDay(for: today)
        var result = self
        while lastDate < todayStart {
            guard let next = calendar.date(byAdding: .day, value: 1, to: lastDate) else { break }
            result.append(DayCount(date: next, count: 0))
            lastDate = next
        }
        return result
    }
}
