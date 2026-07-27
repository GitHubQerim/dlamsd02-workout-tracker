import SwiftUI

/// Pausen-Timer zwischen Sätzen. Wall-clock-basiert (ADR 0003): rechnet bei
/// jedem `TimelineView`-Tick direkt gegen `startDate`, kein akkumulierter
/// Zähler, kein eigener Task/Timer.
struct RestTimerBanner: View {
    let startDate: Date
    let duration: TimeInterval
    let onSkip: () -> Void

    var body: some View {
        TimelineView(.periodic(from: startDate, by: 1)) { context in
            let elapsed = context.date.timeIntervalSince(startDate)
            let remaining = max(0, duration - elapsed)

            DSCard {
                HStack(spacing: DSSpacing.stackGap) {
                    DSProgressRing(
                        value: min(Int(elapsed), Int(duration)),
                        max: Int(duration),
                        size: 56,
                        thickness: 6,
                        label: remaining.formattedClock,
                        labelFont: DSFont.caption
                    )

                    VStack(alignment: .leading, spacing: DSSpacing.s4) {
                        Text("Pause")
                            .font(DSFont.label)
                            .foregroundStyle(DSColor.textSecondary)
                        Text(remaining > 0 ? "noch \(remaining.formattedClock)" : "Pause vorbei")
                            .font(DSFont.body)
                            .foregroundStyle(DSColor.textPrimary)
                    }

                    Spacer()

                    DSButton(title: "Weiter", variant: .outline) {
                        onSkip()
                    }
                }
            }
        }
    }
}
