import Foundation
import SwiftData

/// Ein materialisierter Rekord-Eintrag ("neues Gewichtsmaximum für eine
/// Übung"), analog zu `ChallengeProgressEntry` (ADR 0002/0010) - wird bei
/// Session-Abschluss erkannt und persistiert, nicht live berechnet.
/// Kraft-only: Cardio hat kein Gewicht/Wdh.-Äquivalent (ADR 0009).
@Model
final class PersonalRecord {
    /// Denormalisierter Namens-Snapshot, kein Link zum `Exercise`-Katalog -
    /// nichts muss von hier zurück zum Katalog navigieren.
    var exerciseName: String
    var weightKg: Double
    var reps: Int
    var achievedAt: Date

    var session: WorkoutSession?

    init(exerciseName: String, weightKg: Double, reps: Int, achievedAt: Date = .now) {
        self.exerciseName = exerciseName
        self.weightKg = weightKg
        self.reps = reps
        self.achievedAt = achievedAt
    }
}
