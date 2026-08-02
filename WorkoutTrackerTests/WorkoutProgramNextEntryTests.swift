import Testing
import SwiftData
import Foundation
@testable import WorkoutTracker

@MainActor
struct WorkoutProgramNextEntryTests {
    @Test func nextEntryReturnsNilForProgramWithNoEntries() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let program = WorkoutProgram(name: "Leer")
        context.insert(program)
        try context.save()

        #expect(program.nextEntry(among: try context.fetch(FetchDescriptor<WorkoutSession>())) == nil)
    }

    @Test func nextEntryReturnsFirstEntryWhenNoSessionsExist() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let program = WorkoutProgram(name: "Split")
        context.insert(program)
        let workoutA = Workout(name: "Day A", activityType: .kraft)
        let workoutB = Workout(name: "Day B", activityType: .kraft)
        context.insert(workoutA)
        context.insert(workoutB)
        let entryA = WorkoutProgramEntry(orderIndex: 0, dayLabel: "Day 1", workout: workoutA)
        let entryB = WorkoutProgramEntry(orderIndex: 1, dayLabel: "Day 2", workout: workoutB)
        entryA.program = program
        entryB.program = program
        context.insert(entryA)
        context.insert(entryB)
        try context.save()

        #expect(program.nextEntry(among: try context.fetch(FetchDescriptor<WorkoutSession>()))?.id == entryA.id)
    }

    @Test func nextEntryReturnsFollowingEntryAfterLastCompletedSession() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let program = WorkoutProgram(name: "Split")
        context.insert(program)
        let workoutA = Workout(name: "Day A", activityType: .kraft)
        let workoutB = Workout(name: "Day B", activityType: .kraft)
        context.insert(workoutA)
        context.insert(workoutB)
        let entryA = WorkoutProgramEntry(orderIndex: 0, dayLabel: "Day 1", workout: workoutA)
        let entryB = WorkoutProgramEntry(orderIndex: 1, dayLabel: "Day 2", workout: workoutB)
        entryA.program = program
        entryB.program = program
        context.insert(entryA)
        context.insert(entryB)

        let session = WorkoutSession(activityType: .kraft, endDate: .now)
        session.programEntryID = entryA.id
        context.insert(session)
        try context.save()

        #expect(program.nextEntry(among: try context.fetch(FetchDescriptor<WorkoutSession>()))?.id == entryB.id)
    }

    @Test func nextEntryWrapsAroundAfterLastEntry() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let program = WorkoutProgram(name: "Split")
        context.insert(program)
        let workoutA = Workout(name: "Day A", activityType: .kraft)
        let workoutB = Workout(name: "Day B", activityType: .kraft)
        context.insert(workoutA)
        context.insert(workoutB)
        let entryA = WorkoutProgramEntry(orderIndex: 0, dayLabel: "Day 1", workout: workoutA)
        let entryB = WorkoutProgramEntry(orderIndex: 1, dayLabel: "Day 2", workout: workoutB)
        entryA.program = program
        entryB.program = program
        context.insert(entryA)
        context.insert(entryB)

        let session = WorkoutSession(activityType: .kraft, endDate: .now)
        session.programEntryID = entryB.id
        context.insert(session)
        try context.save()

        #expect(program.nextEntry(among: try context.fetch(FetchDescriptor<WorkoutSession>()))?.id == entryA.id, "Nach dem letzten Tag geht es wieder mit dem ersten weiter")
    }

    /// Deckt den Force-Unwrap-Fix ab: eine Session, deren `programEntryID`
    /// zu keinem aktuellen Eintrag mehr passt (z.B. weil der Tag inzwischen
    /// aus dem Programm entfernt wurde), darf nicht abstürzen - die
    /// Auflösung degradiert stattdessen auf den ersten Eintrag.
    @Test func nextEntryDegradesToFirstEntryWhenLastSessionsEntryWasRemovedFromProgram() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let program = WorkoutProgram(name: "Split")
        context.insert(program)
        let workoutA = Workout(name: "Day A", activityType: .kraft)
        context.insert(workoutA)
        let entryA = WorkoutProgramEntry(orderIndex: 0, dayLabel: "Day 1", workout: workoutA)
        entryA.program = program
        context.insert(entryA)

        let session = WorkoutSession(activityType: .kraft, endDate: .now)
        session.programEntryID = UUID()
        context.insert(session)
        try context.save()

        #expect(program.nextEntry(among: try context.fetch(FetchDescriptor<WorkoutSession>()))?.id == entryA.id)
    }
}
