import Testing
import SwiftData
import Foundation
@testable import WorkoutTracker

@MainActor
struct ChallengeTests {
    @Test func challengeSeedingPopulatesCatalogExactlyOnce() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        UserDefaults.standard.removeObject(forKey: "challengeCatalogSeededV1")
        defer { UserDefaults.standard.removeObject(forKey: "challengeCatalogSeededV1") }

        await ChallengeSeeder.seedIfNeeded(in: context)
        let firstCount = try context.fetchCount(FetchDescriptor<Challenge>())
        #expect(firstCount > 0)

        await ChallengeSeeder.seedIfNeeded(in: context)
        let secondCount = try context.fetchCount(FetchDescriptor<Challenge>())
        #expect(firstCount == secondCount, "Zweiter Seed-Aufruf darf den Katalog nicht erneut befüllen")
    }

    @Test func joinRejectsDuplicateEnrollment() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let challenge = Challenge(name: "Test", challengeType: .streakTage, targetValue: 7)
        context.insert(challenge)
        try context.save()

        let viewModel = ChallengesViewModel(context: context)
        let firstJoin = viewModel.join(challenge)
        let secondJoin = viewModel.join(challenge)

        #expect(firstJoin == true)
        #expect(secondJoin == false)
        #expect(challenge.enrollments.count == 1)
        #expect(viewModel.validationMessage != nil)
    }

    @Test func leaveKeepsProgressHistory() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let challenge = Challenge(name: "Test", challengeType: .streakTage, targetValue: 7)
        context.insert(challenge)
        let session = WorkoutSession(activityType: .kraft, endDate: .now)
        context.insert(session)
        try context.save()

        let viewModel = ChallengesViewModel(context: context)
        viewModel.join(challenge)
        session.materializeChallengeProgress(in: context)
        try context.save()
        #expect(challenge.progressEntries.count == 1)

        let enrollment = challenge.enrollments[0]
        viewModel.leave(enrollment)

        #expect(challenge.enrollments.isEmpty)
        #expect(challenge.progressEntries.count == 1, "Verlassen darf den bisherigen Fortschritts-Log nicht löschen")
    }

    @Test func materializeSkipsChallengesWithoutActiveEnrollment() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let challenge = Challenge(name: "Test", challengeType: .streakTage, targetValue: 7)
        context.insert(challenge)
        let session = WorkoutSession(activityType: .kraft, endDate: .now)
        context.insert(session)
        try context.save()

        session.materializeChallengeProgress(in: context)
        try context.save()

        #expect(challenge.progressEntries.isEmpty)
    }

    @Test func streakChallengeDedupsPerCalendarDay() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let challenge = Challenge(name: "Streak", challengeType: .streakTage, targetValue: 7)
        context.insert(challenge)
        context.insert(ChallengeEnrollment(challenge: challenge))

        let today = Date()
        let sessionA = WorkoutSession(activityType: .kraft, startDate: today, endDate: today)
        let sessionB = WorkoutSession(activityType: .laufen, startDate: today, endDate: today)
        context.insert(sessionA)
        context.insert(sessionB)
        try context.save()

        sessionA.materializeChallengeProgress(in: context)
        sessionB.materializeChallengeProgress(in: context)
        try context.save()

        #expect(challenge.progressEntries.count == 1, "Zwei Sessions am selben Tag dürfen für einen Streak nur einen Eintrag erzeugen")
    }

    @Test func frequencyChallengeDoesNotDedup() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let challenge = Challenge(name: "Frequenz", challengeType: .frequenzProWoche, targetValue: 3)
        context.insert(challenge)
        context.insert(ChallengeEnrollment(challenge: challenge))

        let today = Date()
        let sessionA = WorkoutSession(activityType: .kraft, startDate: today, endDate: today)
        let sessionB = WorkoutSession(activityType: .laufen, startDate: today, endDate: today)
        context.insert(sessionA)
        context.insert(sessionB)
        try context.save()

        sessionA.materializeChallengeProgress(in: context)
        sessionB.materializeChallengeProgress(in: context)
        try context.save()

        #expect(challenge.progressEntries.count == 2, "Frequenz-Challenges zählen jede Session einzeln, kein Dedup")
    }

    @Test func currentStreakDaysBreaksAtGap() throws {
        let calendar = Calendar.current
        let today = Date()
        let challenge = Challenge(name: "Test", challengeType: .streakTage, targetValue: 7)
        let session = WorkoutSession(activityType: .kraft)
        let offsets = [0, -1, -2, -4]
        let entries = offsets.map { offset in
            ChallengeProgressEntry(
                date: calendar.date(byAdding: .day, value: offset, to: today)!,
                value: 1,
                challenge: challenge,
                triggeringSession: session
            )
        }

        let streak = ChallengeInsights.currentStreakDays(entries: entries, calendar: calendar, today: today)

        #expect(streak == 3, "Lücke zwischen Tag -2 und Tag -4 muss die Streak bei 3 abbrechen")
    }

    @Test func currentStreakDaysReturnsZeroWithoutTodayOrYesterdayEntry() throws {
        let calendar = Calendar.current
        let today = Date()
        let challenge = Challenge(name: "Test", challengeType: .streakTage, targetValue: 7)
        let session = WorkoutSession(activityType: .kraft)
        let entry = ChallengeProgressEntry(
            date: calendar.date(byAdding: .day, value: -3, to: today)!,
            value: 1,
            challenge: challenge,
            triggeringSession: session
        )

        let streak = ChallengeInsights.currentStreakDays(entries: [entry], calendar: calendar, today: today)

        #expect(streak == 0)
    }

    @Test func weeklyProgressCountsOnlyCurrentWeek() throws {
        let calendar = Calendar.current
        let today = Date()
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: today)!
        let challenge = Challenge(name: "Test", challengeType: .frequenzProWoche, targetValue: 3)
        let session = WorkoutSession(activityType: .kraft)

        let insideWeek = ChallengeProgressEntry(date: weekInterval.start.addingTimeInterval(3600), value: 1, challenge: challenge, triggeringSession: session)
        let beforeWeek = ChallengeProgressEntry(date: weekInterval.start.addingTimeInterval(-3600), value: 1, challenge: challenge, triggeringSession: session)

        let progress = ChallengeInsights.weeklyProgress(entries: [insideWeek, beforeWeek], calendar: calendar, today: today)

        #expect(progress == 1)
    }

    @Test func currentProgressReturnsStreakDaysForStreakChallenge() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let calendar = Calendar.current
        let today = Date()
        let challenge = Challenge(name: "Streak", challengeType: .streakTage, targetValue: 7)
        context.insert(challenge)
        context.insert(ChallengeEnrollment(challenge: challenge))
        let session = WorkoutSession(activityType: .kraft, startDate: today, endDate: today)
        context.insert(session)
        try context.save()
        session.materializeChallengeProgress(in: context)
        try context.save()

        let progress = ChallengeInsights.currentProgress(for: challenge, calendar: calendar, today: today)

        #expect(progress == 1)
    }

    @Test func currentProgressReturnsWeeklyCountForFrequencyChallenge() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let calendar = Calendar.current
        let today = Date()
        let challenge = Challenge(name: "Frequenz", challengeType: .frequenzProWoche, targetValue: 3)
        context.insert(challenge)
        context.insert(ChallengeEnrollment(challenge: challenge))
        let sessionA = WorkoutSession(activityType: .kraft, startDate: today, endDate: today)
        let sessionB = WorkoutSession(activityType: .laufen, startDate: today, endDate: today)
        context.insert(sessionA)
        context.insert(sessionB)
        try context.save()
        sessionA.materializeChallengeProgress(in: context)
        sessionB.materializeChallengeProgress(in: context)
        try context.save()

        let progress = ChallengeInsights.currentProgress(for: challenge, calendar: calendar, today: today)

        #expect(progress == 2)
    }

    @Test func personalRecordCreatedOnFirstLift() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Kniebeuge")
        context.insert(exercise)
        let session = WorkoutSession(activityType: .kraft, endDate: .now)
        context.insert(session)
        let setLog = SetLog(setIndex: 0, exercise: exercise, reps: 5, weightKg: 60)
        setLog.session = session
        context.insert(setLog)
        try context.save()

        session.detectAndPersistPersonalRecords(in: context)
        try context.save()

        let records = try context.fetch(FetchDescriptor<PersonalRecord>())
        #expect(records.count == 1)
        #expect(records[0].weightKg == 60)
    }

    @Test func personalRecordCreatedOnlyWhenHeavierThanPrior() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Kniebeuge")
        context.insert(exercise)

        let firstSession = WorkoutSession(activityType: .kraft, endDate: .now)
        context.insert(firstSession)
        let firstSet = SetLog(setIndex: 0, exercise: exercise, reps: 5, weightKg: 60)
        firstSet.session = firstSession
        context.insert(firstSet)
        try context.save()
        firstSession.detectAndPersistPersonalRecords(in: context)
        try context.save()

        let heavierSession = WorkoutSession(activityType: .kraft, endDate: .now)
        context.insert(heavierSession)
        let heavierSet = SetLog(setIndex: 0, exercise: exercise, reps: 3, weightKg: 70)
        heavierSet.session = heavierSession
        context.insert(heavierSet)
        try context.save()
        heavierSession.detectAndPersistPersonalRecords(in: context)
        try context.save()

        let equalSession = WorkoutSession(activityType: .kraft, endDate: .now)
        context.insert(equalSession)
        let equalSet = SetLog(setIndex: 0, exercise: exercise, reps: 8, weightKg: 70)
        equalSet.session = equalSession
        context.insert(equalSet)
        try context.save()
        equalSession.detectAndPersistPersonalRecords(in: context)
        try context.save()

        let records = try context.fetch(FetchDescriptor<PersonalRecord>())
        #expect(records.count == 2, "Gleiches Gewicht wie der bisherige Bestwert darf keinen neuen Rekord erzeugen")
        #expect(records.map(\.weightKg).sorted() == [60, 70])
    }

    @Test func cardioSessionsNeverProducePersonalRecords() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let session = WorkoutSession(activityType: .radfahren, endDate: .now)
        context.insert(session)
        let segmentLog = SegmentLog(orderIndex: 0, label: "Sprint", distanceMeters: 10000)
        segmentLog.session = session
        context.insert(segmentLog)
        try context.save()

        session.detectAndPersistPersonalRecords(in: context)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<PersonalRecord>()) == 0)
    }

    @Test func personalRecordCascadeDeletesWithTriggeringSession() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Kniebeuge")
        context.insert(exercise)
        let session = WorkoutSession(activityType: .kraft, endDate: .now)
        context.insert(session)
        let setLog = SetLog(setIndex: 0, exercise: exercise, reps: 5, weightKg: 60)
        setLog.session = session
        context.insert(setLog)
        try context.save()
        session.detectAndPersistPersonalRecords(in: context)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<PersonalRecord>()) == 1)

        context.delete(session)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<PersonalRecord>()) == 0)
    }

    @Test func topVolumeExercisesSumsRepsTimesWeightAcrossCompletedSessions() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let exerciseA = Exercise(name: "A")
        let exerciseB = Exercise(name: "B")
        context.insert(exerciseA)
        context.insert(exerciseB)

        let session = WorkoutSession(activityType: .kraft, endDate: .now)
        context.insert(session)
        let setA1 = SetLog(setIndex: 0, exercise: exerciseA, reps: 10, weightKg: 50)
        let setA2 = SetLog(setIndex: 1, exercise: exerciseA, reps: 8, weightKg: 55)
        let setB1 = SetLog(setIndex: 0, exercise: exerciseB, reps: 5, weightKg: 100)
        setA1.session = session
        setA2.session = session
        setB1.session = session
        context.insert(setA1)
        context.insert(setA2)
        context.insert(setB1)
        try context.save()

        let openSession = WorkoutSession(activityType: .kraft)
        context.insert(openSession)
        let ignoredSet = SetLog(setIndex: 0, exercise: exerciseA, reps: 100, weightKg: 100)
        ignoredSet.session = openSession
        context.insert(ignoredSet)
        try context.save()

        let top = ChallengeInsights.topVolumeExercises(from: [session, openSession], limit: 5)

        let volumeA = try #require(top.first { $0.exerciseName == "A" }?.totalVolume)
        let volumeB = try #require(top.first { $0.exerciseName == "B" }?.totalVolume)
        #expect(volumeA == 940.0, "940kg für A - die offene (nicht abgeschlossene) Session darf nicht mitzählen")
        #expect(volumeB == 500.0)
        #expect(top.first?.exerciseName == "A", "A hat mit 940kg mehr Volumen als B mit 500kg")
    }

    @Test func heatmapDaysAggregatesSessionCountPerDayWithinWindow() throws {
        let calendar = Calendar.current
        let today = Date()
        let sessionToday1 = WorkoutSession(activityType: .kraft, startDate: today, endDate: today)
        let sessionToday2 = WorkoutSession(activityType: .laufen, startDate: today, endDate: today)
        let outsideWindowDate = calendar.date(byAdding: .day, value: -200, to: today)!
        let sessionOutsideWindow = WorkoutSession(activityType: .kraft, startDate: outsideWindowDate, endDate: outsideWindowDate)

        let days = ChallengeInsights.heatmapDays(from: [sessionToday1, sessionToday2, sessionOutsideWindow], weeks: 20, calendar: calendar, today: today)

        let todayEntry = days.first { calendar.isDate($0.date, inSameDayAs: today) }
        #expect(todayEntry?.count == 2)
        #expect(days.allSatisfy { calendar.isDate($0.date, inSameDayAs: today) || $0.date < today })
        #expect(!days.contains { calendar.isDate($0.date, inSameDayAs: outsideWindowDate) }, "Sessions außerhalb des Fensters dürfen nicht auftauchen")
    }

    @Test func weeklyReviewBarsCoversLastSevenDays() throws {
        let calendar = Calendar.current
        let today = Date()
        let bars = ChallengeInsights.weeklyReviewBars(from: [], calendar: calendar, today: today)
        #expect(bars.count == 7)
    }

    @Test func reconcileRankDecayOnAppearUpdatesRankStateAndReturnsWelcomeBackResult() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let calendar = Calendar.current
        let today = Date()

        let rankState = RankState.fetchOrCreate(in: context, calendar: calendar, today: today)
        rankState.currentElo = 50
        rankState.peakElo = 50
        rankState.lastProcessedDay = calendar.date(byAdding: .day, value: -3, to: calendar.startOfDay(for: today))!
        try context.save()

        let viewModel = ChallengesViewModel(context: context)
        let result = viewModel.reconcileRankDecayOnAppear(calendar: calendar, today: today)

        #expect(result.daysDecayed == 2)
        #expect(RankState.fetchOrCreate(in: context, calendar: calendar, today: today).currentElo == 40, "Ergebnis muss über den ViewModel-Aufruf hinweg persistiert sein")
    }
}
