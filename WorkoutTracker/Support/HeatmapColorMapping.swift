import SwiftUI

/// Reine Farb-Zuordnung für die Contribution-Heatmap, geteilt zwischen der
/// App-eigenen `ContributionHeatmapView` und dem Home-Screen-Heatmap-Widget -
/// eine einzige Switch-Logik statt zweier Kopien, die auseinanderlaufen können.
enum HeatmapColorMapping {
    /// `count == 0` darf NICHT `DSColor.surfaceCard` sein - das ist exakt die
    /// Hintergrundfarbe der umgebenden `DSCard`, die "leere" Kachel wäre also
    /// unsichtbar statt (wie bei GitHub) als helle Leer-Kachel erkennbar.
    ///
    /// Drei Stufen statt der früheren Session-Anzahl-Abstufung (0/1/2/3+,
    /// siehe ADR 0015 + Nachtrag dort): ein Tag mit mindestens einer
    /// geloggten Session ist immer "voll" (Accent-Farbe) - keine 3+-Hürde
    /// mehr, das wirkte demotivierend für einzelne harte Trainings. Ein Tag
    /// OHNE geloggte Session, aber mit geschlossenem Move-Ring, bekommt
    /// bewusst NICHT dieselbe volle Farbe, sondern eine mittlere Stufe -
    /// reine Alltagsbewegung soll sichtbar bleiben, aber nicht wie ein
    /// echtes, geloggtes Workout aussehen (Nutzer-Feedback nach echtem
    /// Gerätetest: zu viele Kacheln wirkten "voll", ohne erkennbar zu
    /// machen, was davon tatsächlich Training war).
    static func color(for day: DayCount) -> Color {
        if day.count >= 1 {
            DSColor.accent
        } else if day.moveRingClosed {
            DSColor.green700
        } else {
            DSColor.n700
        }
    }
}
