import Foundation

enum ChallengeType: String, Codable, CaseIterable, Identifiable {
    case streakTage
    case frequenzProWoche

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .streakTage: return "Streak (Tage in Folge)"
        case .frequenzProWoche: return "Frequenz (pro Woche)"
        }
    }
}
