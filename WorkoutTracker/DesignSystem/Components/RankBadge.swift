import SwiftUI

/// Rang-Badge fürs Elo-/Gamification-System (ADR 0014). Bewusste, eng
/// gescopte Ausnahme vom "DSIcon = nur eigene SVGs"-Prinzip: sieben eigene
/// Trophäen-/Medaillen-SVGs wären ein eigener Design-Auftrag, kein Teil
/// dieses Coding-Passes. Ein einziges SF Symbol, je Rang eingefärbt, statt
/// eines nicht zusammenpassenden Icon-Sets pro Rang.
struct RankBadge: View {
    let tier: RankTier
    var size: CGFloat = 48

    private var tint: Color {
        switch tier {
        case .bronze: return DSColor.rankBronze
        case .silver: return DSColor.rankSilver
        case .gold: return DSColor.rankGold
        case .platin: return DSColor.rankPlatin
        case .diamond: return DSColor.rankDiamond
        case .master: return DSColor.rankMaster
        case .challenger: return DSColor.rankChallenger
        }
    }

    var body: some View {
        Image(systemName: "seal.fill")
            .font(.system(size: size))
            .foregroundStyle(tint)
            .accessibilityLabel("Rang \(tier.displayName)")
    }
}
