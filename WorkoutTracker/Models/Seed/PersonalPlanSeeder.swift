import Foundation
import SwiftData

/// Importiert den persönlichen 6-Tage-Push/Pull/Legs-Split des Nutzers
/// einmalig - bewusst NICHT wie `ExerciseSeeder`/`ChallengeSeeder`
/// automatisch beim App-Start (das wären generische Starter-Kataloge für
/// jede Installation), sondern manuell über den Debug-Button in
/// `SettingsView` ausgelöst. Idempotent über einen Namens-Check statt eines
/// globalen `UserDefaults`-Flags, da es sich um eine bewusste, einmalige
/// Nutzeraktion handelt statt eines automatischen Erst-Start-Vorgangs.
///
/// Persönlicher Debug-Komfort, kein generalisiertes Feature: gehört nicht
/// zum bewerteten DLAMSD02-Projektbericht-Umfang (siehe Projekt-Memory) und
/// ist bewusst `#if DEBUG`-only, damit es nie in einem Release-Build landet.
enum PersonalPlanSeeder {
    private static let programName = "Push Pull Legs"

    @MainActor
    static func seed(in context: ModelContext) {
        let name = Self.programName
        let alreadySeeded = (try? context.fetchCount(FetchDescriptor<WorkoutProgram>(
            predicate: #Predicate { $0.name == name }
        ))) ?? 0
        guard alreadySeeded == 0 else { return }

        // `exerciseCache` ist hier kein reines Performance-Detail: mehrere
        // Übungen tauchen innerhalb dieses einen Seed-Laufs wortgleich
        // mehrfach auf (z.B. "Face Pulls" in Pull A und B, der geteilte
        // `calfBlock` in Legs A und B) - ohne Cache würde ein zweiter Fetch
        // die noch nicht gespeicherte erste Instanz ggf. nicht finden und
        // eine zweite `Exercise` mit demselben (`.unique`) Namen anlegen,
        // was beim `context.save()` unten fehlschlagen würde.
        var exerciseCache: [String: Exercise] = [:]
        /// Exakter Namens-Match gegen den bestehenden Katalog (z.B.
        /// "Beinpresse" aus `ExerciseSeeder`) - bewusst KEIN Fuzzy-Matching:
        /// "Bankdrücken (LH)" und "KH-Bankdrücken" sind unterschiedliche
        /// Übungen mit eigener Gewichtsskala und bleiben getrennte
        /// `Exercise`-Einträge, sonst würde die Personal-Record-Erkennung
        /// Langhantel- und Kurzhantel-Varianten fälschlich vermischen.
        /// `ExercisePickerView.createCustomExercise()` hat einen ähnlichen
        /// Fetch-oder-Anlegen-Ablauf, aber bewusst case-insensitive (dort
        /// geht es um Tippfehler bei Nutzereingabe) - hier zählt exakte
        /// Übereinstimmung mit den Namen aus der Trainingsplan-Vorlage,
        /// beide Stellen wurden deshalb nicht zu einer Abstraktion
        /// zusammengeführt.
        func exercise(_ exerciseName: String, _ muscleGroup: MuscleGroup) -> Exercise {
            if let cached = exerciseCache[exerciseName] { return cached }
            let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.name == exerciseName })
            if let existing = try? context.fetch(descriptor).first {
                exerciseCache[exerciseName] = existing
                return existing
            }
            let created = Exercise(name: exerciseName, muscleGroup: muscleGroup, isCustom: true)
            context.insert(created)
            exerciseCache[exerciseName] = created
            return created
        }

        func makeWorkout(_ workoutName: String, _ entries: [(name: String, muscleGroup: MuscleGroup, sets: Int, reps: Int)]) -> Workout {
            let workout = Workout(name: workoutName, activityType: .kraft)
            context.insert(workout)
            for (index, entry) in entries.enumerated() {
                let plannedExercise = PlannedExercise(
                    orderIndex: index,
                    exercise: exercise(entry.name, entry.muscleGroup),
                    targetSets: entry.sets,
                    targetReps: entry.reps
                )
                plannedExercise.plan = workout
                context.insert(plannedExercise)
            }
            return workout
        }

        // Wiederholungs-Bereiche aus dem PDF (z.B. "6-8") werden als
        // Untergrenze übernommen, einzelne Werte (z.B. "15") direkt. Die
        // "Pause"-Spalte wird nicht übernommen - laut Nutzer app-weit
        // hardcoded, kein Per-Übung-Feld im Datenmodell.
        let calfBlock: [(name: String, muscleGroup: MuscleGroup, sets: Int, reps: Int)] = [
            ("Wadenheben stehend", .beine, 4, 15),
            ("Tibialis-Raises", .beine, 3, 15),
        ]

        let pushA = makeWorkout("Push A", [
            ("Bankdrücken (LH)", .brust, 4, 6),
            ("Schrägbank KH", .brust, 3, 8),
            ("Schulterdrücken (KH)", .schultern, 3, 8),
            ("Seitheben (KH)", .schultern, 4, 12),
            ("Trizeps Pushdown", .arme, 3, 10),
            ("Overhead Extension", .arme, 3, 12),
        ])

        let pushB = makeWorkout("Push B", [
            ("KH-Bankdrücken", .brust, 3, 10),
            ("Brustpresse / Butterfly", .brust, 3, 12),
            ("Arnold Press", .schultern, 3, 10),
            ("Seitheben (Kabel)", .schultern, 3, 15),
            ("Dips (assistiert ok)", .brust, 3, 10),
            ("Trizeps Kickbacks", .arme, 3, 12),
        ])

        let pullA = makeWorkout("Pull A", [
            ("Klimmzüge / Lat Pulldown", .ruecken, 4, 6),
            ("Rudern Langhantel", .ruecken, 4, 8),
            ("Einarm-KH-Rudern", .ruecken, 3, 10),
            ("Face Pulls", .ruecken, 3, 15),
            ("SZ-Curls", .arme, 3, 8),
            ("Hammer Curls", .arme, 3, 12),
        ])

        let pullB = makeWorkout("Pull B", [
            ("Lat Pulldown (eng/neutral)", .ruecken, 3, 10),
            ("Kabelrudern sitzend", .ruecken, 3, 10),
            ("Reverse Flys / Rear Delt", .ruecken, 3, 15),
            ("Face Pulls", .ruecken, 3, 15),
            ("Preacher Curls", .arme, 3, 10),
            ("Kabel-Curls", .arme, 3, 12),
        ])

        let legsA = makeWorkout("Legs A", [
            ("Kniebeugen (LH)", .beine, 4, 6),
            ("Rumänisches Kreuzheben", .beine, 3, 8),
            ("Beinpresse", .beine, 3, 10),
            ("Ausfallschritte (KH)", .beine, 3, 10),
        ] + calfBlock)

        let legsB = makeWorkout("Legs B", [
            ("Hip Thrust", .beine, 4, 10),
            ("Beinpresse (hoch)", .beine, 3, 15),
            ("Leg Curls", .beine, 3, 12),
            ("Bulgarian Split Squats", .beine, 3, 10),
            ("Leg Extensions", .beine, 3, 15),
        ] + calfBlock)

        let program = WorkoutProgram(name: Self.programName)
        context.insert(program)
        for (index, workout) in [pushA, pullA, legsA, pushB, pullB, legsB].enumerated() {
            let entry = WorkoutProgramEntry(orderIndex: index, dayLabel: "Day \(index + 1)", workout: workout)
            entry.program = program
            context.insert(entry)
        }

        do {
            try context.save()
        } catch {
            assertionFailure("Personal-Plan-Seeding fehlgeschlagen: \(error)")
        }
    }
}
