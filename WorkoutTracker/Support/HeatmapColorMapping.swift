import SwiftUI

/// Reine Farb-Zuordnung für die Contribution-Heatmap, geteilt zwischen der
/// App-eigenen `ContributionHeatmapView` und dem Home-Screen-Heatmap-Widget -
/// eine einzige Switch-Logik statt zweier Kopien, die auseinanderlaufen können.
enum HeatmapColorMapping {
    /// `count == 0` darf NICHT `DSColor.surfaceCard` sein - das ist exakt die
    /// Hintergrundfarbe der umgebenden `DSCard`, die "leere" Kachel wäre also
    /// unsichtbar statt (wie bei GitHub) als helle Leer-Kachel erkennbar.
    static func color(for count: Int) -> Color {
        switch count {
        case 0: DSColor.n700
        case 1: DSColor.green850
        case 2: DSColor.green700
        default: DSColor.accent
        }
    }
}
