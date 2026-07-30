import Foundation
import SwiftData

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
    func nextEntry(in context: ModelContext) -> WorkoutProgramEntry? {
        let orderedEntries = entries.sorted { $0.orderIndex < $1.orderIndex }
        guard !orderedEntries.isEmpty else { return nil }

        let entryIDs = Set(orderedEntries.map(\.id))
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.endDate != nil && $0.programEntryID != nil },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        guard let recentSessions = try? context.fetch(descriptor) else { return orderedEntries.first }

        // Kein Force-Unwrap auf `programEntryID!`: das vorherige Fetch-
        // Predicate kombiniert zwei Optional-nil-Checks mit `&&`, was in
        // diesem SwiftData-Setup nicht immer zuverlässig durchgesetzt wird
        // (ADR 0001) - ein sicheres Un-wrap hier behebt das Risiko
        // unabhängig davon, ob das Predicate tatsächlich der Auslöser ist.
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
