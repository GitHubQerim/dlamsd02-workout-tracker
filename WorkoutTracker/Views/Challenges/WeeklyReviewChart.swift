import SwiftUI
import Charts

/// Mini-Chart: Sessions pro Tag der letzten 7 Kalendertage.
struct WeeklyReviewChart: View {
    let bars: [DayCount]

    var body: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSSpacing.s8) {
                Text("Wochenrückblick")
                    .font(DSFont.label)
                    .foregroundStyle(DSColor.textSecondary)
                Chart(bars) { day in
                    BarMark(
                        x: .value("Tag", day.date, unit: .day),
                        y: .value("Sessions", day.count)
                    )
                    .foregroundStyle(DSColor.accent)
                }
                .frame(height: 120)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow))
                    }
                }
                .chartYAxis(.hidden)
            }
        }
    }
}
