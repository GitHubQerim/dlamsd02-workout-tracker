import Foundation

/// Die Rang-Stufen des lokalen Elo-/Gamification-Systems, League-of-Legends-
/// artig benannt. Reine Benennung/Reihenfolge - Elo-Schwellen und alle
/// Gewinn-/Verfalls-Konstanten leben bewusst in `RankTuning`
/// (`Support/RankEngine.swift`), nicht hier, damit dieses Enum wie
/// `ActivityType` frei von tunbarer Business-Logik bleibt.
enum RankTier: Int, CaseIterable, Comparable {
    case bronze
    case silver
    case gold
    case platin
    case diamond
    case master
    case challenger

    var displayName: String {
        switch self {
        case .bronze: return "Bronze"
        case .silver: return "Silver"
        case .gold: return "Gold"
        case .platin: return "Platin"
        case .diamond: return "Diamond"
        case .master: return "Master"
        case .challenger: return "Challenger"
        }
    }

    static func < (lhs: RankTier, rhs: RankTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
