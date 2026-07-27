import Foundation
import SwiftData

@Model
final class ChallengeProgressEntry {
    var date: Date
    var value: Double // z.B. 1.0 für einen Streak-Tag, Beitrag bei Frequenz
    var challenge: Challenge?
    var triggeringSession: WorkoutSession?

    init(date: Date = .now, value: Double, challenge: Challenge, triggeringSession: WorkoutSession) {
        self.date = date
        self.value = value
        self.challenge = challenge
        self.triggeringSession = triggeringSession
    }
}
