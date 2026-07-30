import Testing
import SwiftData
import Foundation
@testable import WorkoutTracker

@MainActor
struct RankTests {
    // MARK: - Tier-Lookup

    @Test func tierForEloReturnsBronzeAtZero() throws {
        #expect(RankEngine.tier(forElo: 0) == .bronze)
    }

    @Test func tierForEloReturnsCorrectTierAtEachExactThreshold() throws {
        for entry in RankTuning.tierThresholds {
            #expect(RankEngine.tier(forElo: entry.minElo) == entry.tier)
        }
    }

    @Test func tierForEloReturnsPreviousTierJustBelowThreshold() throws {
        #expect(RankEngine.tier(forElo: 499) == .bronze)
        #expect(RankEngine.tier(forElo: 999) == .silver)
        #expect(RankEngine.tier(forElo: 1599) == .gold)
        #expect(RankEngine.tier(forElo: 2199) == .platin)
        #expect(RankEngine.tier(forElo: 2799) == .diamond)
        #expect(RankEngine.tier(forElo: 3399) == .master)
    }

    @Test func tierForEloClampsAtChallengerAboveTopThreshold() throws {
        #expect(RankEngine.tier(forElo: 10_000) == .challenger)
    }

    @Test func tierProgressReturnsMaxedRingAtChallenger() throws {
        let progress = RankEngine.tierProgress(forElo: 5000)
        #expect(progress.value == 1)
        #expect(progress.max == 1)
    }

    @Test func tierProgressReturnsRelativeProgressWithinSpan() throws {
        // 750 liegt zwischen Silver (500) und Gold (1000).
        let progress = RankEngine.tierProgress(forElo: 750)
        #expect(progress.value == 250)
        #expect(progress.max == 500)
    }

    // MARK: - Streak (extrahiert)

    @Test func dayStreakCalculatorBreaksAtGap() throws {
        let calendar = Calendar.current
        let today = Date()
        let uniqueDays = Set([0, -1, -2, -4].map { calendar.startOfDay(for: calendar.date(byAdding: .day, value: $0, to: today)!) })

        let streak = DayStreakCalculator.currentStreak(uniqueDays: uniqueDays, calendar: calendar, today: today)

        #expect(streak == 3, "Lücke zwischen Tag -2 und Tag -4 muss die Streak bei 3 abbrechen")
    }

    @Test func dayStreakCalculatorReturnsZeroWithoutTodayOrYesterday() throws {
        let calendar = Calendar.current
        let today = Date()
        let uniqueDays = Set([calendar.startOfDay(for: calendar.date(byAdding: .day, value: -3, to: today)!)])

        let streak = DayStreakCalculator.currentStreak(uniqueDays: uniqueDays, calendar: calendar, today: today)

        #expect(streak == 0)
    }

    @Test func globalStreakDaysCountsAcrossActivityTypes() throws {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let sessionToday = WorkoutSession(activityType: .kraft, startDate: today, endDate: today)
        let sessionYesterday = WorkoutSession(activityType: .laufen, startDate: yesterday, endDate: yesterday)
        let openSession = WorkoutSession(activityType: .kraft, startDate: today)

        let streak = RankEngine.globalStreakDays(from: [sessionToday, sessionYesterday, openSession], calendar: calendar, today: today)

        #expect(streak == 2, "Kraft und Cardio zählen gleichermaßen, offene Sessions werden ignoriert")
    }

    // MARK: - Überlastungs-Bonus

    @Test func overloadBonusAwardsTwoEloPerStartedFivePercentIncrease() throws {
        // 12% Steigerung -> ceil(12/5) = 3 Schritte * 2 Elo = 6.
        let bonus = RankEngine.overloadBonus(
            currentVolumeByExercise: ["A": 112],
            previousVolumeByExercise: ["A": 100]
        )
        #expect(bonus == 6)
    }

    @Test func overloadBonusCapsAtTwentyPerExercise() throws {
        let bonus = RankEngine.overloadBonus(
            currentVolumeByExercise: ["A": 1000],
            previousVolumeByExercise: ["A": 100]
        )
        #expect(bonus == 20)
    }

    @Test func overloadBonusIgnoresExerciseWithoutPreviousVolume() throws {
        let bonus = RankEngine.overloadBonus(
            currentVolumeByExercise: ["A": 100],
            previousVolumeByExercise: [:]
        )
        #expect(bonus == 0)
    }

    @Test func overloadBonusIgnoresZeroOrNegativeChange() throws {
        let bonus = RankEngine.overloadBonus(
            currentVolumeByExercise: ["A": 100, "B": 90],
            previousVolumeByExercise: ["A": 100, "B": 100]
        )
        #expect(bonus == 0)
    }

    @Test func overloadBonusSumsAcrossExercisesThenCapsSessionTotalAtForty() throws {
        let bonus = RankEngine.overloadBonus(
            currentVolumeByExercise: ["A": 1000, "B": 1000, "C": 1000],
            previousVolumeByExercise: ["A": 10, "B": 10, "C": 10]
        )
        // Jede Übung würde einzeln den 20er-Deckel treffen (3*20=60),
        // Session-Gesamtdeckel greift bei 40.
        #expect(bonus == 40)
    }

    // MARK: - Reconciliation

    @Test func reconcileAppliesBaseBonusAndStreakBoostOnFirstSessionOfDay() throws {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let result = RankEngine.reconcile(
            currentElo: 0, peakElo: 0, lastProcessedDay: yesterday, today: today, calendar: calendar,
            currentStreakDays: 3, sessionCompletedToday: true, overloadBonusThisSession: 0
        )

        #expect(result.eloDelta == 18, "15 Basis + 3 Streak-Boost")
        #expect(result.daysDecayed == 0)
    }

    @Test func reconcileDoesNotReapplyBaseBonusOrStreakBoostForSecondSessionSameDay() throws {
        let calendar = Calendar.current
        let today = Date()
        let todayStart = calendar.startOfDay(for: today)

        let result = RankEngine.reconcile(
            currentElo: 100, peakElo: 100, lastProcessedDay: todayStart, today: today, calendar: calendar,
            currentStreakDays: 5, sessionCompletedToday: true, overloadBonusThisSession: 5
        )

        #expect(result.eloDelta == 5, "Basis/Streak-Boost nur bei der ersten Session des Tages, hier nur der Überlastungs-Bonus")
    }

    @Test func reconcileStreakBoostCapsAtTwenty() throws {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let result = RankEngine.reconcile(
            currentElo: 0, peakElo: 0, lastProcessedDay: yesterday, today: today, calendar: calendar,
            currentStreakDays: 50, sessionCompletedToday: true
        )

        #expect(result.eloDelta == 35, "15 Basis + gedeckelte 20 Streak-Boost, nicht 50")
    }

    @Test func reconcileComebackMultiplierAppliesWhenBelowPeakAndStreakAtLeastSeven() throws {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let result = RankEngine.reconcile(
            currentElo: 100, peakElo: 500, lastProcessedDay: yesterday, today: today, calendar: calendar,
            currentStreakDays: 7, sessionCompletedToday: true
        )

        #expect(result.comebackActive == true)
        #expect(result.eloDelta == 44, "(15 Basis + 7 Streak-Boost) * 2")
    }

    @Test func reconcileComebackMultiplierDoesNotApplyAtOrAbovePeak() throws {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let result = RankEngine.reconcile(
            currentElo: 500, peakElo: 500, lastProcessedDay: yesterday, today: today, calendar: calendar,
            currentStreakDays: 10, sessionCompletedToday: true
        )

        #expect(result.comebackActive == false)
        #expect(result.eloDelta == 25, "15 Basis + 10 Streak-Boost ohne Multiplikator")
    }

    @Test func reconcileComebackMultiplierDoesNotApplyBelowSevenDayStreak() throws {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let result = RankEngine.reconcile(
            currentElo: 100, peakElo: 500, lastProcessedDay: yesterday, today: today, calendar: calendar,
            currentStreakDays: 6, sessionCompletedToday: true
        )

        #expect(result.comebackActive == false)
    }

    @Test func reconcileCatchesUpMultiDayDecayBeforeApplyingTodaysGain() throws {
        let calendar = Calendar.current
        let today = Date()
        let fourDaysAgo = calendar.date(byAdding: .day, value: -4, to: today)!

        let result = RankEngine.reconcile(
            currentElo: 100, peakElo: 100, lastProcessedDay: fourDaysAgo, today: today, calendar: calendar,
            currentStreakDays: 1, sessionCompletedToday: true
        )

        #expect(result.daysDecayed == 3)
        #expect(result.decayElo == 15)
        #expect(result.eloDelta == 1, "-15 Decay + 16 Gewinn (15 Basis + 1 Streak-Boost)")
    }

    @Test func reconcileDecayFlooredAtZero() throws {
        let calendar = Calendar.current
        let today = Date()
        let tenDaysAgo = calendar.date(byAdding: .day, value: -10, to: today)!

        let result = RankEngine.reconcile(
            currentElo: 5, peakElo: 5, lastProcessedDay: tenDaysAgo, today: today, calendar: calendar,
            sessionCompletedToday: false
        )

        #expect(result.newElo == 0)
    }

    @Test func reconcileDecayOnlyAppliesNoGain() throws {
        let calendar = Calendar.current
        let today = Date()
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!

        let result = RankEngine.reconcile(
            currentElo: 50, peakElo: 50, lastProcessedDay: twoDaysAgo, today: today, calendar: calendar,
            currentStreakDays: 99, sessionCompletedToday: false, overloadBonusThisSession: 99
        )

        #expect(result.eloDelta == -5, "Nur Decay (1 verpasster Tag), Streak/Überlastung werden bei sessionCompletedToday == false ignoriert")
    }

    @Test func reconcileNeverRegressesLastProcessedDayWhenTodayIsBeforeIt() throws {
        // Simuliert eine über Mitternacht laufende Session: Trigger 2
        // (ChallengesView, echtes .now) hat lastProcessedDay bereits auf
        // "heute" vorangetrieben, bevor Trigger 1 (Session-Abschluss) mit
        // `today: trainedOn` = "gestern" (dem Start der Session) aufruft.
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let todayStart = calendar.startOfDay(for: today)

        let result = RankEngine.reconcile(
            currentElo: 100, peakElo: 100, lastProcessedDay: todayStart, today: yesterday, calendar: calendar,
            currentStreakDays: 1, sessionCompletedToday: true
        )

        #expect(result.daysDecayed == 0, "Keine Rückwärts-Decay durch die verspätete Session")
        #expect(result.newLastProcessedDay == todayStart, "lastProcessedDay darf nie zurückfallen")
        #expect(result.awardedDailyBonus == false, "Der Tag gilt bereits als verarbeitet, kein doppelter Basis-Bonus")
    }

    @Test func reconcileAwardedDailyBonusIsFalseOnSecondSessionSameDay() throws {
        let calendar = Calendar.current
        let today = Date()
        let todayStart = calendar.startOfDay(for: today)

        let result = RankEngine.reconcile(
            currentElo: 16, peakElo: 16, lastProcessedDay: todayStart, today: today, calendar: calendar,
            currentStreakDays: 1, sessionCompletedToday: true, overloadBonusThisSession: 8
        )

        #expect(result.awardedDailyBonus == false)
        #expect(result.eloDelta == 8)
    }

    @Test func reconcileDecayOnlyIsIdempotentWithinSameDay() throws {
        let calendar = Calendar.current
        let today = Date()
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!

        let first = RankEngine.reconcile(
            currentElo: 50, peakElo: 50, lastProcessedDay: twoDaysAgo, today: today, calendar: calendar,
            sessionCompletedToday: false
        )
        let second = RankEngine.reconcile(
            currentElo: first.newElo, peakElo: first.newPeakElo, lastProcessedDay: first.newLastProcessedDay,
            today: today, calendar: calendar, sessionCompletedToday: false
        )

        #expect(second.eloDelta == 0)
        #expect(second.daysDecayed == 0)
        #expect(second.newLastProcessedDay == first.newLastProcessedDay)
    }

    @Test func reconcileDecayOnlyAdvancesLastProcessedDayToYesterdayNotToday() throws {
        let calendar = Calendar.current
        let today = Date()
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        let expectedYesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: today))!

        let result = RankEngine.reconcile(
            currentElo: 50, peakElo: 50, lastProcessedDay: twoDaysAgo, today: today, calendar: calendar,
            sessionCompletedToday: false
        )

        #expect(result.newLastProcessedDay == expectedYesterday)
    }

    @Test func reconcileUpdatesPeakEloOnlyWhenNewEloExceedsIt() throws {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let belowPeak = RankEngine.reconcile(
            currentElo: 50, peakElo: 100, lastProcessedDay: yesterday, today: today, calendar: calendar,
            sessionCompletedToday: true
        )
        #expect(belowPeak.newPeakElo == 100, "65 < 100, Peak bleibt unverändert")

        let abovePeak = RankEngine.reconcile(
            currentElo: 90, peakElo: 100, lastProcessedDay: yesterday, today: today, calendar: calendar,
            sessionCompletedToday: true
        )
        #expect(abovePeak.newPeakElo == 105, "90 + 15 = 105 > 100, neuer Peak")
    }

    @Test func reconcileReturnsOldAndNewTierForRankUpDetection() throws {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let result = RankEngine.reconcile(
            currentElo: 490, peakElo: 490, lastProcessedDay: yesterday, today: today, calendar: calendar,
            sessionCompletedToday: true
        )

        #expect(result.oldTier == .bronze)
        #expect(result.newTier == .silver)
    }

    // MARK: - Integration (SwiftData)

    @Test func rankStateFetchOrCreateInsertsSingletonAtEloZero() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let rankState = RankState.fetchOrCreate(in: context)
        try context.save()

        #expect(rankState.currentElo == 0)
        #expect(rankState.peakElo == 0)
        #expect(try context.fetchCount(FetchDescriptor<RankState>()) == 1)
    }

    @Test func rankStateFetchOrCreateReturnsExistingRowNotADuplicate() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let first = RankState.fetchOrCreate(in: context)
        try context.save()
        first.currentElo = 42
        try context.save()

        let second = RankState.fetchOrCreate(in: context)

        #expect(second.currentElo == 42)
        #expect(try context.fetchCount(FetchDescriptor<RankState>()) == 1)
    }

    @Test func updateRankProgressAwardsBaseBonusAndStreakBoostOnFirstSessionOfDay() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let today = Date()

        // Cardio, um den Überlastungs-Bonus (nur Kraft) aus der Rechnung
        // herauszuhalten und Basis+Streak isoliert zu prüfen.
        let session = WorkoutSession(activityType: .laufen, startDate: today, endDate: today)
        context.insert(session)
        try context.save()

        let result = session.updateRankProgress(in: context)
        try context.save()

        #expect(result.eloDelta == 16, "15 Basis + 1 Streak-Boost (erster Trainingstag zählt als Streak-Tag 1)")
        let rankState = RankState.fetchOrCreate(in: context)
        #expect(rankState.currentElo == 16)
    }

    @Test func updateRankProgressAppliesOverloadBonusForImprovedStrengthVolume() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Bankdrücken")
        context.insert(exercise)
        let today = Date()

        let sessionA = WorkoutSession(activityType: .kraft, startDate: today, endDate: today)
        context.insert(sessionA)
        let setA = SetLog(setIndex: 0, exercise: exercise, reps: 10, weightKg: 50)
        setA.session = sessionA
        context.insert(setA)
        try context.save()
        _ = sessionA.updateRankProgress(in: context)
        try context.save()

        let laterToday = today.addingTimeInterval(60)
        let sessionB = WorkoutSession(activityType: .kraft, startDate: laterToday, endDate: laterToday)
        context.insert(sessionB)
        let setB = SetLog(setIndex: 0, exercise: exercise, reps: 10, weightKg: 60)
        setB.session = sessionB
        context.insert(setB)
        try context.save()
        let resultB = sessionB.updateRankProgress(in: context)
        try context.save()

        #expect(resultB.eloDelta == 8, "20% Volumensteigerung (500 -> 600) = 4 Schritte * 2 Elo, keine Basis/Streak an der zweiten Session desselben Tages")
        let rankState = RankState.fetchOrCreate(in: context)
        #expect(rankState.currentElo == 24)
    }

    @Test func updateRankProgressSkipsOverloadBonusForCardioSession() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let today = Date()

        let sessionA = WorkoutSession(activityType: .laufen, startDate: today, endDate: today)
        context.insert(sessionA)
        try context.save()
        _ = sessionA.updateRankProgress(in: context)
        try context.save()

        let laterToday = today.addingTimeInterval(60)
        let sessionB = WorkoutSession(activityType: .laufen, startDate: laterToday, endDate: laterToday)
        context.insert(sessionB)
        try context.save()
        let resultB = sessionB.updateRankProgress(in: context)

        #expect(resultB.eloDelta == 0, "Cardio hat keinen Überlastungs-Bonus, zweite Session desselben Tages bringt daher nichts mehr")
    }

    @Test func updateRankProgressAdvancesLastProcessedDayToSessionDay() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let calendar = Calendar.current
        let today = Date()

        let session = WorkoutSession(activityType: .laufen, startDate: today, endDate: today)
        context.insert(session)
        try context.save()
        _ = session.updateRankProgress(in: context)
        try context.save()

        let rankState = RankState.fetchOrCreate(in: context)
        #expect(calendar.isDate(rankState.lastProcessedDay, inSameDayAs: today))
    }

    @Test func updateRankProgressCatchesUpMultiDayDecayBeforeTodaysGain() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let calendar = Calendar.current
        let today = Date()

        let rankState = RankState.fetchOrCreate(in: context)
        rankState.currentElo = 100
        rankState.peakElo = 100
        rankState.lastProcessedDay = calendar.date(byAdding: .day, value: -4, to: calendar.startOfDay(for: today))!
        try context.save()

        let session = WorkoutSession(activityType: .laufen, startDate: today, endDate: today)
        context.insert(session)
        try context.save()
        let result = session.updateRankProgress(in: context)
        try context.save()

        #expect(result.daysDecayed == 3)
        #expect(result.decayElo == 15)
        #expect(result.newElo == 101, "100 - 15 Decay + 16 Gewinn (15 Basis + 1 Streak-Tag)")
    }

    @Test func reconcileDecayOnlyOnAppearAppliesDecayWithoutGain() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let calendar = Calendar.current
        let today = Date()

        let rankState = RankState.fetchOrCreate(in: context, calendar: calendar, today: today)
        rankState.currentElo = 50
        rankState.peakElo = 50
        rankState.lastProcessedDay = calendar.date(byAdding: .day, value: -3, to: calendar.startOfDay(for: today))!
        try context.save()

        let result = RankState.reconcileDecayOnly(in: context, calendar: calendar, today: today)

        #expect(result.daysDecayed == 2)
        #expect(result.decayElo == 10)
        #expect(result.newElo == 40)
        #expect(RankState.fetchOrCreate(in: context, calendar: calendar, today: today).currentElo == 40)
    }

    @Test func reconcileDecayOnlyOnAppearIsIdempotentAcrossRepeatedCallsSameDay() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let calendar = Calendar.current
        let today = Date()

        let rankState = RankState.fetchOrCreate(in: context, calendar: calendar, today: today)
        rankState.currentElo = 50
        rankState.peakElo = 50
        rankState.lastProcessedDay = calendar.date(byAdding: .day, value: -3, to: calendar.startOfDay(for: today))!
        try context.save()

        _ = RankState.reconcileDecayOnly(in: context, calendar: calendar, today: today)
        let second = RankState.reconcileDecayOnly(in: context, calendar: calendar, today: today)

        #expect(second.eloDelta == 0)
        #expect(second.daysDecayed == 0)
    }

    @Test func mostRecentCompletedSessionSharedHelperMatchesPreviousBehavior() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Kniebeuge")
        context.insert(exercise)

        let older = WorkoutSession(activityType: .kraft, endDate: .now)
        context.insert(older)
        let olderSet = SetLog(setIndex: 0, exercise: exercise, reps: 5, weightKg: 50)
        olderSet.session = older
        context.insert(olderSet)
        older.startDate = Date(timeIntervalSinceNow: -7200)

        let newer = WorkoutSession(activityType: .kraft, endDate: .now)
        context.insert(newer)
        let newerSet = SetLog(setIndex: 0, exercise: exercise, reps: 5, weightKg: 60)
        newerSet.session = newer
        context.insert(newerSet)
        newer.startDate = Date(timeIntervalSinceNow: -3600)

        let openSession = WorkoutSession(activityType: .kraft)
        context.insert(openSession)
        let openSet = SetLog(setIndex: 0, exercise: exercise, reps: 5, weightKg: 999)
        openSet.session = openSession
        context.insert(openSet)

        try context.save()

        let mostRecent = WorkoutSession.mostRecentCompletedSession(containingExerciseName: "Kniebeuge", excluding: UUID(), in: context)
        #expect(mostRecent?.id == newer.id, "offene Session wird ignoriert, unter den abgeschlossenen gewinnt die neuere")

        let excludingNewer = WorkoutSession.mostRecentCompletedSession(containingExerciseName: "Kniebeuge", excluding: newer.id, in: context)
        #expect(excludingNewer?.id == older.id)
    }
}
