import Foundation

extension WorkoutProgram {
    /// Welcher Tag als Nächstes dran ist: der auf den zuletzt abgeschlossenen
    /// Tag folgende Eintrag, mit Wrap-around nach dem letzten Tag. `nil` nur,
    /// wenn das Programm gar keine Einträge hat.
    ///
    /// Matched über `WorkoutSession.programEntryID` (nicht über Namen/Label -
    /// die sind nicht eindeutig, siehe ADR zur Programm-Tages-Auflösung),
    /// damit Umbenennungen/Umsortierungen die Zuordnung nicht stillschweigend
    /// verfälschen. Wurde der zuletzt gemachte Tag inzwischen aus dem
    /// Programm entfernt, degradiert die Auflösung auf den ersten Eintrag
    /// statt abzustürzen oder nichts anzuzeigen.
    ///
    /// Nimmt bewusst ein bereits geladenes `[WorkoutSession]`-Array statt
    /// selbst per `context.fetch(...)` zu laden: ein imperativer Fetch aus
    /// einem SwiftUI-`body`-Aufrufpfad heraus (dieser Typ wird u.a. aus
    /// `WorkoutProgramDetailView.body` gelesen) geriet mit SwiftData's
    /// Change-Tracking in eine Endlosschleife - `body` wertete sich dadurch
    /// unbegrenzt neu aus (100% CPU, App hängt beim Öffnen eines Tages).
    /// Aufrufer liefern die Sessions über ein eigenes `@Query`, das SwiftUI
    /// korrekt beobachtet.
    func nextEntry(among candidateSessions: [WorkoutSession]) -> WorkoutProgramEntry? {
        let orderedEntries = entries.sorted { $0.orderIndex < $1.orderIndex }
        guard !orderedEntries.isEmpty else { return nil }

        let entryIDs = Set(orderedEntries.map(\.id))
        let recentSessions = candidateSessions
            .filter { $0.endDate != nil && $0.programEntryID != nil }
            .sorted { $0.startDate > $1.startDate }

        // Kein Force-Unwrap auf `programEntryID!`: siehe ADR 0001 zu
        // fragilen Compound-Optional-Predicates in diesem SwiftData-Setup -
        // ein sicheres Un-wrap hier behebt das Risiko unabhängig davon, ob
        // das ursprüngliche Predicate tatsächlich der Auslöser war.
        guard
            let lastEntryID = recentSessions.first(where: { session in
                guard let entryID = session.programEntryID else { return false }
                return entryIDs.contains(entryID)
            })?.programEntryID,
            let lastIndex = orderedEntries.firstIndex(where: { $0.id == lastEntryID })
        else {
            return orderedEntries.first
        }

        return orderedEntries[(lastIndex + 1) % orderedEntries.count]
    }
}

extension WorkoutProgramEntry {
    var nextDayDisplayText: String { "weiter mit \(dayLabel): \(workoutName)" }
}
