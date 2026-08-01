import Testing
import SwiftData
import Foundation
@testable import WorkoutTracker

@MainActor
struct PersonalPlanSeederTests {
    @Test func seedCreatesSixWorkoutsWithoutProgram() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        PersonalPlanSeeder.seed(in: context)

        let workouts = try context.fetch(FetchDescriptor<Workout>())
        #expect(workouts.count == 6)
        #expect(Set(workouts.map(\.name)) == [
            "Push A - schwer", "Push B - Pump",
            "Pull A - schwer", "Pull B - Pump",
            "Legs A - schwer", "Legs B - leicht",
        ])

        let programs = try context.fetch(FetchDescriptor<WorkoutProgram>())
        #expect(programs.isEmpty, "Seeder legt bewusst kein WorkoutProgram an - Nutzer stellt den Plan selbst zusammen")
    }

    @Test func seedIsIdempotent() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        PersonalPlanSeeder.seed(in: context)
        PersonalPlanSeeder.seed(in: context)

        let workouts = try context.fetch(FetchDescriptor<Workout>())
        #expect(workouts.count == 6, "Zweiter Aufruf darf die Workouts nicht erneut anlegen")
    }

    @Test func seedReusesExistingExerciseByExactName() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let existing = Exercise(name: "Beinpresse", muscleGroup: .beine, isCustom: false)
        context.insert(existing)
        try context.save()

        PersonalPlanSeeder.seed(in: context)

        let matches = try context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.name == "Beinpresse" }))
        #expect(matches.count == 1, "Ein bereits vorhandener Katalog-Eintrag darf nicht dupliziert werden")
        #expect(matches.first?.isCustom == false, "Der bestehende Eintrag bleibt unverändert, wird nicht überschrieben")
    }
}
