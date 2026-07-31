import SwiftUI

/// Detailansicht einer beigetretenen Challenge: Fortschritts-Ring +
/// vollständige Historie der `ChallengeProgressEntry`-Einträge.
struct ChallengeDetailView: View {
    let challenge: Challenge

    private var progress: Int {
        ChallengeInsights.currentProgress(for: challenge)
    }

    private var enrolledAt: Date? {
        challenge.enrollments.first?.enrolledAt
    }

    private var sortedEntries: [ChallengeProgressEntry] {
        challenge.progressEntries.sorted { $0.date > $1.date }
    }

    var body: some View {
        DSWashedScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.sectionGap) {
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
                                Text(challenge.challengeType.displayName)
                                    .font(DSFont.body)
                                    .foregroundStyle(DSColor.textPrimary)
                                Text("Ziel: \(challenge.targetValue)")
                                    .font(DSFont.caption)
                                    .foregroundStyle(DSColor.textSecondary)
                                if let enrolledAt {
                                    Text("Beigetreten seit \(enrolledAt.formatted(date: .abbreviated, time: .omitted))")
                                        .font(DSFont.caption)
                                        .foregroundStyle(DSColor.textTertiary)
                                }
                            }
                            Spacer()
                        }
                    }

                    Text("Verlauf")
                        .font(DSFont.label)
                        .foregroundStyle(DSColor.textSecondary)

                    if sortedEntries.isEmpty {
                        DSCard {
                            Text("Noch keine Einträge")
                                .font(DSFont.caption)
                                .foregroundStyle(DSColor.textTertiary)
                        }
                    } else {
                        VStack(spacing: DSSpacing.cardGap) {
                            ForEach(sortedEntries) { entry in
                                ChallengeProgressEntryRow(entry: entry)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(challenge.name)
    }
}

private struct ChallengeProgressEntryRow: View {
    let entry: ChallengeProgressEntry

    private var sessionContext: String? {
        guard let session = entry.triggeringSession else { return nil }
        return session.programName ?? session.plan?.name ?? session.activityType.displayName
    }

    var body: some View {
        DSCard {
            HStack {
                VStack(alignment: .leading, spacing: DSSpacing.s4) {
                    Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                        .font(DSFont.body)
                        .foregroundStyle(DSColor.textPrimary)
                    if let sessionContext {
                        Text(sessionContext)
                            .font(DSFont.caption)
                            .foregroundStyle(DSColor.textSecondary)
                    }
                }
                Spacer()
            }
        }
    }
}

#Preview {
    NavigationStack {
        ChallengeDetailView(challenge: Challenge(name: "30-Tage-Streak", challengeType: .streakTage, targetValue: 30))
    }
}
