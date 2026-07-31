import Testing
import SwiftData
import Foundation
@testable import WorkoutTracker

@MainActor
struct PersonalPlanSeederTests {
    @Test func seedCreatesSixWorkoutsUnderOneProgram() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        PersonalPlanSeeder.seed(in: context)

        let programs = try context.fetch(FetchDescriptor<WorkoutProgram>())
        #expect(programs.count == 1)
        #expect(programs.first?.entries.count == 6)

        let workouts = try context.fetch(FetchDescriptor<Workout>())
        #expect(workouts.count == 6)
    }

    @Test func seedIsIdempotent() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        PersonalPlanSeeder.seed(in: context)
        PersonalPlanSeeder.seed(in: context)

        let programs = try context.fetch(FetchDescriptor<WorkoutProgram>())
        #expect(programs.count == 1, "Zweiter Aufruf darf das Programm nicht erneut anlegen")
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
