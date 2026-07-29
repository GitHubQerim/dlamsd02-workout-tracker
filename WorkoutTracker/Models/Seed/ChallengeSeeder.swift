import Foundation
import SwiftData

/// Befüllt den Challenge-Katalog beim allerersten Start mit einem festen
/// Grundstock an Streak-/Frequenz-Challenges - analog zu `ExerciseSeeder`.
/// Fester Katalog statt frei anlegbarer Challenges (bewusste Design-
/// Entscheidung, siehe Plan zu Phase D).
enum ChallengeSeeder {
    private static let seededFlagKey = "challengeCatalogSeededV1"

    @MainActor
    static func seedIfNeeded(in context: ModelContext) async {
        // Gleiche Begründung wie ExerciseSeeder: kein "fetchCount == 0"-Check,
        // ein einmaliges Flag ist die korrekte "seed genau einmal"-Semantik.
        guard !UserDefaults.standard.bool(forKey: seededFlagKey) else { return }

        for seed in starterCatalog {
            context.insert(Challenge(name: seed.name, challengeType: seed.type, targetValue: seed.targetValue))
        }

        do {
            try context.save()
            UserDefaults.standard.set(true, forKey: seededFlagKey)
        } catch {
            assertionFailure("Challenge-Seeding fehlgeschlagen: \(error)")
        }
    }

    private static let starterCatalog: [(name: String, type: ChallengeType, targetValue: Int)] = [
        ("7-Tage-Streak", .streakTage, 7),
        ("30-Tage-Streak", .streakTage, 30),
        ("3x pro Woche", .frequenzProWoche, 3),
        ("5x pro Woche", .frequenzProWoche, 5),
    ]
}
