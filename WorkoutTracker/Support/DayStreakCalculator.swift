import Foundation

/// Ausgelagerte Kernlogik einer Kalendertage-Streak - ursprünglich Teil von
/// `ChallengeInsights.currentStreakDays` (Challenge-Fortschritts-Einträge),
/// jetzt gemeinsam genutzt von dieser UND der globalen, Session-basierten
/// Streak (`RankEngine.globalStreakDays`), damit der Rückwärtslauf-
/// Algorithmus nicht zweimal existiert.
enum DayStreakCalculator {
    /// Zählt konsekutive Kalendertage rückwärts ab dem neuesten Tag in
    /// `uniqueDays`, bricht bei der ersten Lücke ab. `0`, wenn weder heute
    /// noch gestern in `uniqueDays` enthalten ist (Streak bereits gerissen).
    static func currentStreak(uniqueDays: Set<Date>, calendar: Calendar = .current, today: Date = .now) -> Int {
        let todayStart = calendar.startOfDay(for: today)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: todayStart) else { return 0 }

        let anchor: Date
        if uniqueDays.contains(todayStart) {
            anchor = todayStart
        } else if uniqueDays.contains(yesterday) {
            anchor = yesterday
        } else {
            return 0
        }

        var streak = 0
        var cursor = anchor
        while uniqueDays.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }
}
