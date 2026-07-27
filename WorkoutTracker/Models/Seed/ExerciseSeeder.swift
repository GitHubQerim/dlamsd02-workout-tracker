import Foundation
import SwiftData

/// Befüllt den Exercise-Katalog beim allerersten Start mit einem kleinen
/// Grundstock gängiger Kraftübungen, damit die App nicht komplett leer ist.
enum ExerciseSeeder {
    private static let seededFlagKey = "exerciseCatalogSeededV1"

    @MainActor
    static func seedIfNeeded(in context: ModelContext) async {
        // Bewusst kein "fetchCount == 0"-Check: Löscht der Nutzer später
        // absichtlich seinen ganzen Katalog, würde ein reiner Leer-Check
        // beim nächsten Start ungewollt wieder auffüllen. Ein einmaliges,
        // versioniertes Flag ist die korrekte "seed genau einmal"-Semantik.
        guard !UserDefaults.standard.bool(forKey: seededFlagKey) else { return }

        for seed in starterCatalog {
            context.insert(Exercise(name: seed.name, muscleGroup: seed.muscleGroup, executionHint: seed.hint, isCustom: false))
        }

        do {
            try context.save()
            UserDefaults.standard.set(true, forKey: seededFlagKey)
        } catch {
            // Absichtlich kein Flag setzen bei Fehler - nächster Start
            // versucht es erneut.
            assertionFailure("Seeding fehlgeschlagen: \(error)")
        }
    }

    private static let starterCatalog: [(name: String, muscleGroup: MuscleGroup, hint: String?)] = [
        ("Kniebeuge", .beine, "Rücken gerade halten, Knie in Zehenrichtung."),
        ("Kreuzheben", .ruecken, "Stange nah am Körper führen."),
        ("Bankdrücken", .brust, "Schulterblätter zusammenziehen und fixieren."),
        ("Schulterdrücken", .schultern, nil),
        ("Klimmzug", .ruecken, nil),
        ("Rudern vorgebeugt", .ruecken, nil),
        ("Bizepscurls", .arme, nil),
        ("Trizepsdrücken", .arme, nil),
        ("Beinpresse", .beine, nil),
        ("Ausfallschritte", .beine, nil),
        ("Plank", .bauch, "Becken nicht durchhängen lassen."),
        ("Crunches", .bauch, nil),
        ("Seitheben", .schultern, nil),
        ("Latzug", .ruecken, nil),
    ]
}
