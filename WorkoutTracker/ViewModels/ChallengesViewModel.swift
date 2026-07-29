import Foundation
import SwiftData

/// Mutierende Aktionen für Challenges - bewusst schlank (nur `join`/`leave`),
/// keine Lesewerte hier (siehe `ChallengeInsights`, das direkt auf per
/// `@Query` geladenen Arrays arbeitet, ohne ViewModel-Kopplung).
@Observable
@MainActor
final class ChallengesViewModel {
    private(set) var validationMessage: String?

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Verhindert doppelten Beitritt zur selben Challenge - reine ViewModel-
    /// Invariante, keine DB-Constraint (gleiches Muster wie
    /// `WorkoutProgramEditorViewModel.setDefault`, ADR 0008).
    @discardableResult
    func join(_ challenge: Challenge) -> Bool {
        guard challenge.enrollments.isEmpty else {
            validationMessage = "Du bist \(challenge.name) bereits beigetreten."
            return false
        }
        let enrollment = ChallengeEnrollment(challenge: challenge)
        context.insert(enrollment)
        do {
            try context.save()
            return true
        } catch {
            validationMessage = "Beitreten fehlgeschlagen: \(error.localizedDescription)"
            return false
        }
    }

    /// Löscht nur die Anmeldung - der bisherige Fortschritts-Log bleibt
    /// bestehen (kein rückwirkendes Löschen/Zurücksetzen, siehe ADR-0002-
    /// Nachtrag Phase D).
    func leave(_ enrollment: ChallengeEnrollment) {
        context.delete(enrollment)
        do {
            try context.save()
        } catch {
            validationMessage = "Verlassen fehlgeschlagen: \(error.localizedDescription)"
        }
    }
}
