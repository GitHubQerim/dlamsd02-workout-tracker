import Foundation
import SwiftData

extension WorkoutSession {
    /// Erzeugt beim Session-Abschluss die materialisierten `ChallengeProgressEntry`-
    /// Einträge für alle aktuell beigetretenen Challenges (ADR 0002/0002-Nachtrag
    /// Phase D). Jede Sportart zählt gleichermaßen.
    ///
    /// Gating bewusst einfach gehalten: eine Challenge bekommt nur dann einen
    /// Eintrag, wenn im Moment des Session-Abschlusses mindestens eine
    /// `ChallengeEnrollment` existiert - kein rückwirkendes Nachtragen für
    /// Sessions vor dem Beitritt, kein Reset bei Verlassen+erneutem Beitritt.
    /// Bereits bestehende Einträge bleiben unangetastet (siehe ADR-0002-Nachtrag).
    func materializeChallengeProgress(in context: ModelContext) {
        guard let challenges = try? context.fetch(FetchDescriptor<Challenge>()) else { return }
        let calendar = Calendar.current
        // `startDate` statt `.now` - der Tag, an dem trainiert wurde, nicht der
        // Moment, in dem diese Funktion zufällig läuft. Macht die Zähl-Regel
        // außerdem deterministisch testbar (Tests setzen `startDate` frei).
        let trainedOn = startDate

        for challenge in challenges where !challenge.enrollments.isEmpty {
            switch challenge.challengeType {
            case .streakTage:
                // Höchstens ein Eintrag pro Kalendertag - Streak zählt Tage,
                // nicht Sessions.
                let alreadyLoggedThatDay = challenge.progressEntries.contains {
                    calendar.isDate($0.date, inSameDayAs: trainedOn)
                }
                guard !alreadyLoggedThatDay else { continue }
                let entry = ChallengeProgressEntry(date: trainedOn, value: 1.0, challenge: challenge, triggeringSession: self)
                context.insert(entry)

            case .frequenzProWoche:
                // Kein Dedup - jede abgeschlossene Session zählt zur Wochen-Frequenz.
                let entry = ChallengeProgressEntry(date: trainedOn, value: 1.0, challenge: challenge, triggeringSession: self)
                context.insert(entry)
            }
        }
    }
}
