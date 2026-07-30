import Foundation
import SwiftData

/// Persistierter Elo-/Rang-Zustand des lokalen Gamification-Systems (ADR
/// 0014) - GENAU EINE Zeile pro App-Installation (erste Singleton-
/// Persistenz in diesem Codebase; Challenges/PersonalRecords sind alle
/// Mehrzeilen-Modelle). Immer über `fetchOrCreate(in:)` lesen/anlegen, nie
/// direkt `RankState(...)` an anderer Stelle inserten.
@Model
final class RankState {
    var currentElo: Int
    var peakElo: Int
    /// Letzter Kalendertag, für den Elo-Gewinn ODER Inaktivitäts-Decay
    /// bereits abschließend verarbeitet wurde - siehe `RankEngine.reconcile`
    /// für die Invariante, die darauf aufbaut.
    var lastProcessedDay: Date

    /// `fileprivate`: die einzige erlaubte Erzeugung läuft über
    /// `fetchOrCreate(in:)` in dieser Datei - ein `RankState(...)` an
    /// anderer Stelle würde eine zweite Zeile riskieren und die
    /// "genau eine Zeile"-Invariante nur noch per Konvention halten statt
    /// vom Compiler erzwungen.
    fileprivate init(currentElo: Int = 0, peakElo: Int = 0, lastProcessedDay: Date = .now) {
        self.currentElo = currentElo
        self.peakElo = peakElo
        self.lastProcessedDay = lastProcessedDay
    }

    /// Holt die einzige `RankState`-Zeile oder legt bei erster Nutzung eine
    /// frische an. `lastProcessedDay` der frischen Zeile wird bewusst auf
    /// GESTERN (relativ zu `today`) gesetzt, nicht auf heute: sonst würde
    /// die allererste Session desselben Tages fälschlich als "heute schon
    /// verarbeitet" gelten und ihren Basis-/Streak-Bonus verlieren (siehe
    /// `RankEngine.reconcile`, `daysBetween >= 1`-Bedingung).
    static func fetchOrCreate(in context: ModelContext, calendar: Calendar = .current, today: Date = .now) -> RankState {
        var descriptor = FetchDescriptor<RankState>()
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let todayStart = calendar.startOfDay(for: today)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
        let fresh = RankState(lastProcessedDay: yesterday)
        context.insert(fresh)
        return fresh
    }
}
