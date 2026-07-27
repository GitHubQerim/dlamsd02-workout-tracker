import SwiftUI

/// Pausen-Timer als eigener Vollbild-Screen (per `.fullScreenCover`
/// präsentiert, kein Inline-Banner mehr - deutlicherer Moment im Flow).
/// Wall-clock-basiert (ADR 0003): rechnet bei jedem `TimelineView`-Tick
/// direkt gegen `startDate`, kein akkumulierter Zähler, kein eigener
/// Task/Timer. `onAdjust` verändert nur die Zieldauer, nie `startDate` -
/// keine Sprünge, die Restzeit wird ab dem nächsten Tick einfach korrekt neu
/// berechnet.
struct RestTimerView: View {
    let startDate: Date
    let duration: TimeInterval
    let exerciseName: String
    let onAdjust: (TimeInterval) -> Void
    let onSkip: () -> Void

    var body: some View {
        TimelineView(.periodic(from: startDate, by: 1)) { context in
            let elapsed = context.date.timeIntervalSince(startDate)
            let remaining = max(0, duration - elapsed)

            DSWashedScreen {
                VStack(spacing: DSSpacing.s24) {
                    Spacer()

                    Text("Pause nach \(exerciseName)")
                        .font(DSFont.body)
                        .foregroundStyle(DSColor.textSecondary)
                        .multilineTextAlignment(.center)

                    DSProgressRing(
                        value: min(Int(elapsed), Int(duration)),
                        max: max(1, Int(duration)),
                        size: 220,
                        thickness: 14,
                        label: remaining.formattedClock,
                        labelFont: DSFont.manrope(size: 64, weight: 700)
                    )

                    HStack(spacing: DSSpacing.s24) {
                        DSButton(title: "-10s", variant: .outline) {
                            onAdjust(-10)
                        }
                        .accessibilityLabel("Pause um 10 Sekunden verkürzen")

                        DSButton(title: "+10s", variant: .outline) {
                            onAdjust(10)
                        }
                        .accessibilityLabel("Pause um 10 Sekunden verlängern")
                    }

                    Spacer()

                    DSButton(title: "Weiter", fullWidth: true) {
                        onSkip()
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}
