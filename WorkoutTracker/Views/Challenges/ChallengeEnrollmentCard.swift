import SwiftUI

/// Karte für eine beigetretene Challenge: Fortschritts-Ring + "Verlassen".
struct ChallengeEnrollmentCard: View {
    let challenge: Challenge
    let onLeave: () -> Void

    private var progress: Int {
        ChallengeInsights.currentProgress(for: challenge)
    }

    var body: some View {
        DSCard {
            HStack(spacing: DSSpacing.cardGap) {
                DSProgressRing(
                    value: min(progress, challenge.targetValue),
                    max: challenge.targetValue,
                    size: 64,
                    thickness: 6,
                    label: "\(progress)",
                    labelFont: DSFont.body
                )
                VStack(alignment: .leading, spacing: DSSpacing.s4) {
                    Text(challenge.name)
                        .font(DSFont.body)
                        .foregroundStyle(DSColor.textPrimary)
                    Text(challenge.challengeType.displayName)
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textSecondary)
                }
                Spacer()
                Button("Verlassen", action: onLeave)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textTertiary)
            }
        }
    }
}
