import Foundation
import SwiftData

@Model
final class ChallengeEnrollment {
    var enrolledAt: Date
    var challenge: Challenge?

    init(enrolledAt: Date = .now, challenge: Challenge) {
        self.enrolledAt = enrolledAt
        self.challenge = challenge
    }
}
