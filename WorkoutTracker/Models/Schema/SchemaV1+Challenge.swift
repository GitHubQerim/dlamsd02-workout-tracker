import Foundation
import SwiftData

@Model
final class Challenge {
    var name: String
    var challengeType: ChallengeType
    var targetValue: Int // Tage (Streak) bzw. Sessions/Woche (Frequenz)
    var startDate: Date
    var endDate: Date?

    // .cascade: eine Enrollment ohne ihre Challenge ist bedeutungslos.
    @Relationship(deleteRule: .cascade, inverse: \ChallengeEnrollment.challenge)
    var enrollments: [ChallengeEnrollment] = []

    // .cascade: Löschen einer ganzen Challenge-Definition räumt
    // konsequent auch ihren eigenen Progress-Log auf.
    @Relationship(deleteRule: .cascade, inverse: \ChallengeProgressEntry.challenge)
    var progressEntries: [ChallengeProgressEntry] = []

    init(name: String, challengeType: ChallengeType, targetValue: Int, startDate: Date = .now, endDate: Date? = nil) {
        self.name = name
        self.challengeType = challengeType
        self.targetValue = targetValue
        self.startDate = startDate
        self.endDate = endDate
    }
}
