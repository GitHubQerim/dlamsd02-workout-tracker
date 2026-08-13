import Foundation

/// Ein Übungs-Volumen-Aggregat für die Top-5-Auswertung.
struct ExerciseVolume: Identifiable {
    let exerciseName: String
    let totalVolume: Double
    var id: String { exerciseName }
}

/// Reine, zustandslose Auswertungsfunktionen für die Challenges-/Auswertungen-
/// Ansicht - operieren auf bereits per `@Query` geladenen Arrays, kein
/// `ModelContext` nötig, trivial ohne `ModelContainer` testbar. `calendar`/
/// `today` sind bewusst injizierbar (Default `.current`/`.now`), damit Tests
/// deterministisch bleiben statt vom echten Tagesdatum abzuhängen.
enum ChallengeInsights {
    /// Top-N-Übungen nach Trainingsvolumen (Σ Wdh. × Gewicht je Satz), nur
    /// abgeschlossene Sessions, alle `SetLog`s zählen unabhängig vom
    /// `isCompleted`-Häkchen (Konsistenz mit `previousAttempt()`, ADR-0002-
    /// Nachtrag Phase D).
    static func topVolumeExercises(from sessions: [WorkoutSession], limit: Int = 5) -> [ExerciseVolume] {
        let completedSetLogs = sessions.filter { $0.endDate != nil }.flatMap(\.setLogs)
        let grouped = volumeByExercise(completedSetLogs)
        let volumes = grouped.map { exerciseName, totalVolume in
            ExerciseVolume(exerciseName: exerciseName, totalVolume: totalVolume)
        }
        return Array(volumes.sorted { $0.totalVolume > $1.totalVolume }.prefix(limit))
    }

    /// Trainingsvolumen (Σ Wdh. × Gewicht je Satz) gruppiert nach Übungsname
    /// - gemeinsame Formel für `topVolumeExercises` und den Überlastungs-
    /// Bonus des Rang-Systems (ADR 0014, `WorkoutSession.updateRankProgress`),
    /// damit "was zählt als Volumen" nur an einer Stelle definiert ist.
    /// Warm-up-Sätze zählen bewusst nie mit - weder in die Analytics noch in
    /// den Rang-Fortschritt.
    static func volumeByExercise(_ setLogs: [SetLog]) -> [String: Double] {
        Dictionary(grouping: setLogs.filter { !$0.isWarmup }, by: \.exerciseName)
            .mapValues { logs in logs.reduce(0) { $0 + Double($1.reps) * $1.weightKg } }
    }

    /// Ein Aggregat (Session-Anzahl) pro Kalendertag über ein rollierendes
    /// Fenster von `weeks` Wochen, endend heute - Grundlage für den
    /// Contribution-Style-Heatmap.
    static func heatmapDays(
        from sessions: [WorkoutSession],
        weeks: Int = 20,
        calendar: Calendar = .current,
        today: Date = .now
    ) -> [DayCount] {
        let todayStart = calendar.startOfDay(for: today)
        guard let windowStart = calendar.date(byAdding: .day, value: -(weeks * 7 - 1), to: todayStart) else {
            return []
        }

        var countsByDay: [Date: Int] = [:]
        for session in sessions where session.endDate != nil {
            let day = calendar.startOfDay(for: session.startDate)
            guard day >= windowStart else { continue }
            countsByDay[day, default: 0] += 1
        }

        var result: [DayCount] = []
        var cursor = windowStart
        while cursor <= todayStart {
            result.append(DayCount(date: cursor, count: countsByDay[cursor] ?? 0))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    /// Sessions pro Tag der letzten 7 Kalendertage - Grundlage für den
    /// Wochenrückblick-Mini-Chart. Wiederverwendung von `heatmapDays` mit
    /// `weeks: 1`, keine eigene Aggregationslogik nötig.
    static func weeklyReviewBars(from sessions: [WorkoutSession], calendar: Calendar = .current, today: Date = .now) -> [DayCount] {
        heatmapDays(from: sessions, weeks: 1, calendar: calendar, today: today)
    }

    /// Aktuelle Streak-Länge in Tagen: zählt konsekutive Kalendertage
    /// rückwärts ab dem neuesten Eintrag, bricht bei der ersten Lücke ab.
    /// `0`, wenn der neueste Eintrag weder heute noch gestern liegt (Streak
    /// bereits gerissen). Kernlogik ausgelagert in `DayStreakCalculator`,
    /// gemeinsam genutzt mit der globalen Rang-Streak (`RankEngine.globalStreakDays`).
    static func currentStreakDays(entries: [ChallengeProgressEntry], calendar: Calendar = .current, today: Date = .now) -> Int {
        let uniqueDays = Set(entries.map { calendar.startOfDay(for: $0.date) })
        return DayStreakCalculator.currentStreak(uniqueDays: uniqueDays, calendar: calendar, today: today)
    }

    /// Anzahl Fortschritts-Einträge in der laufenden ISO-Kalenderwoche -
    /// Grundlage für den Frequenz-Fortschrittsring.
    static func weeklyProgress(entries: [ChallengeProgressEntry], calendar: Calendar = .current, today: Date = .now) -> Int {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: today) else { return 0 }
        return entries.filter { weekInterval.contains($0.date) }.count
    }

    /// Aktueller Fortschrittswert einer Challenge, je nach `challengeType`
    /// entweder die Streak-Länge oder der Wochenfrequenz-Zähler - gemeinsam
    /// genutzt von `ChallengeEnrollmentCard` und `ChallengeDetailView`.
    static func currentProgress(for challenge: Challenge, calendar: Calendar = .current, today: Date = .now) -> Int {
        switch challenge.challengeType {
        case .streakTage:
            currentStreakDays(entries: challenge.progressEntries, calendar: calendar, today: today)
        case .frequenzProWoche:
            weeklyProgress(entries: challenge.progressEntries, calendar: calendar, today: today)
        }
    }
}
