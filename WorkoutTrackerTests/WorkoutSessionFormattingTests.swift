import Testing
import SwiftData
import Foundation
@testable import WorkoutTracker

@MainActor
struct WorkoutSessionFormattingTests {
    @Test func completedVolumeKgCountsOnlyCompletedSets() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Kniebeuge")
        context.insert(exercise)

        let session = WorkoutSession(activityType: .kraft)
        context.insert(session)

        let completedSet = SetLog(setIndex: 0, exercise: exercise, reps: 10, weightKg: 50, isCompleted: true)
        completedSet.session = session
        context.insert(completedSet)

        let openSet = SetLog(setIndex: 1, exercise: exercise, reps: 10, weightKg: 999, isCompleted: false)
        openSet.session = session
        context.insert(openSet)

        try context.save()

        #expect(session.completedVolumeKg == 500)
    }

    @Test func completedVolumeKgIsZeroWithoutCompletedSets() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Kniebeuge")
        context.insert(exercise)

        let session = WorkoutSession(activityType: .kraft)
        context.insert(session)

        let openSet = SetLog(setIndex: 0, exercise: exercise, reps: 10, weightKg: 50, isCompleted: false)
        openSet.session = session
        context.insert(openSet)

        try context.save()

        #expect(session.completedVolumeKg == 0)
    }
}
