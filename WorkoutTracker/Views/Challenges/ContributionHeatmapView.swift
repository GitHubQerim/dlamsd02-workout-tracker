import SwiftUI

/// Contribution-Style-Heatmap: eine Kachel pro Kalendertag, 7 Zeilen
/// (Wochentage), scrollt horizontal über die Wochen (`LazyHGrid`, nicht
/// `LazyVGrid` - ein GitHub-Style-Graph ist spaltenweise nach Wochen).
struct ContributionHeatmapView: View {
    let days: [DayCount]

    private let cellSize: CGFloat = 14
    private let rows = Array(repeating: GridItem(.fixed(14), spacing: 4), count: 7)

    /// `count == 0` darf NICHT `DSColor.surfaceCard` sein - das ist exakt die
    /// Hintergrundfarbe der umgebenden `DSCard`, die "leere" Kachel wäre also
    /// unsichtbar statt (wie bei GitHub) als helle Leer-Kachel erkennbar.
    private func color(for count: Int) -> Color {
        switch count {
        case 0: DSColor.n700
        case 1: DSColor.green850
        case 2: DSColor.green700
        default: DSColor.accent
        }
    }

    var body: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSSpacing.s8) {
                Text("Trainings-Heatmap")
                    .font(DSFont.label)
                    .foregroundStyle(DSColor.textSecondary)
                // `days` ist chronologisch aufsteigend (älteste Woche zuerst,
                // rechteste Spalte = heute) - ohne expliziten Scroll-Befehl
                // startet die ScrollView links bei der ältesten Woche, "heute"
                // liegt dann unsichtbar außerhalb des Bildschirms.
                // `.defaultScrollAnchor` griff in dieser verschachtelten
                // ScrollView-Situation (horizontal in vertikal) nicht
                // zuverlässig - `ScrollViewReader` + `scrollTo` ist explizit.
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHGrid(rows: rows, spacing: 4) {
                            ForEach(days) { day in
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(color(for: day.count))
                                    .frame(width: cellSize, height: cellSize)
                                    .id(day.id)
                            }
                        }
                    }
                    .onAppear {
                        if let mostRecentDay = days.last {
                            proxy.scrollTo(mostRecentDay.id, anchor: .trailing)
                        }
                    }
                }
            }
        }
    }
}
