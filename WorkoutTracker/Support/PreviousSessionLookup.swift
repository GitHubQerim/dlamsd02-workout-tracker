import Foundation
import SwiftData

extension WorkoutSession {
    /// Letzte ABGESCHLOSSENE, andere Session, die mindestens einen Satz zu
    /// `exerciseName` enthält - gemeinsamer Fetch+Scan, genutzt von
    /// `WorkoutSessionViewModel.previousAttempt(for:)` (UI-"Letztes Mal"-
    /// Vergleich) UND dem Überlastungs-Bonus in `RankReconciliation.swift`
    /// (ADR 0014). Bewusst kein `#Predicate` über die `setLogs`-Relationship
    /// (siehe ADR 0001: SwiftData kann Relationship-Traversierung dort nicht
    /// zuverlässig abbilden) - stattdessen ein einfacher, nach Datum
    /// sortierter Fetch aller fremden abgeschlossenen Sessions, danach
    /// Swift-seitiger Scan mit frühem Abbruch beim ersten Treffer.
    static func mostRecentCompletedSession(
        containingExerciseName exerciseName: String,
        excluding excludedID: UUID,
        in context: ModelContext
    ) -> WorkoutSession? {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.endDate != nil && $0.id != excludedID },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        guard let candidates = try? context.fetch(descriptor) else { return nil }
        return candidates.first { candidate in
            candidate.setLogs.contains { $0.exerciseName == exerciseName }
        }
    }
}
