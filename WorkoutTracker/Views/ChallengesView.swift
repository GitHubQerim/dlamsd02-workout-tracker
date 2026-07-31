import SwiftUI
import SwiftData

/// Challenges (fester Katalog, Beitritt, Streak-/Frequenz-Fortschritt) +
/// Auswertungen (Wochenrückblick, Heatmap, Top-5-Volumen, letzte Rekorde) -
/// Phase D.
struct ChallengesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Challenge.name) private var challenges: [Challenge]
    @Query(sort: \WorkoutSession.startDate, order: .reverse) private var sessions: [WorkoutSession]
    @Query(sort: \PersonalRecord.achievedAt, order: .reverse) private var personalRecords: [PersonalRecord]
    @Query private var rankStates: [RankState]

    @State private var viewModel: ChallengesViewModel?
    @State private var rankWelcomeBack: RankReconciliationResult?

    private var completedSessions: [WorkoutSession] {
        sessions.filter { $0.endDate != nil }
    }

    private var enrolledChallenges: [Challenge] {
        challenges.filter { !$0.enrollments.isEmpty }
    }

    private var catalogChallenges: [Challenge] {
        challenges.filter { $0.enrollments.isEmpty }
    }

    private var rankState: RankState? { rankStates.first }

    var body: some View {
        DSWashedScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.sectionGap) {
                    Text("Challenges")
                        .font(DSFont.screenTitle)
                        .foregroundStyle(DSColor.textPrimary)

                    if let rankState {
                        RankSectionCard(
                            elo: rankState.currentElo,
                            tier: RankEngine.tier(forElo: rankState.currentElo),
                            streakDays: RankEngine.globalStreakDays(from: completedSessions),
                            welcomeBack: rankWelcomeBack
                        )
                    }

                    if !enrolledChallenges.isEmpty {
                        Text("Deine Challenges")
                            .font(DSFont.label)
                            .foregroundStyle(DSColor.textSecondary)
                        VStack(spacing: DSSpacing.cardGap) {
                            ForEach(enrolledChallenges) { challenge in
                                if let enrollment = challenge.enrollments.first {
                                    NavigationLink {
                                        ChallengeDetailView(challenge: challenge)
                                    } label: {
                                        ChallengeEnrollmentCard(challenge: challenge) {
                                            viewModel?.leave(enrollment)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    if !catalogChallenges.isEmpty {
                        Text("Weitere Challenges")
                            .font(DSFont.label)
                            .foregroundStyle(DSColor.textSecondary)
                        VStack(spacing: DSSpacing.cardGap) {
                            ForEach(catalogChallenges) { challenge in
                                ChallengeCatalogRow(challenge: challenge) {
                                    viewModel?.join(challenge)
                                }
                            }
                        }
                    }

                    Text("Auswertungen")
                        .font(DSFont.label)
                        .foregroundStyle(DSColor.textSecondary)

                    WeeklyReviewChart(bars: ChallengeInsights.weeklyReviewBars(from: completedSessions))
                    ContributionHeatmapView(days: ChallengeInsights.heatmapDays(from: completedSessions))
                    TopVolumeList(exercises: ChallengeInsights.topVolumeExercises(from: completedSessions))
                    RecentPersonalRecordsList(records: Array(personalRecords.prefix(5)))
                }
            }
        }
        .navigationTitle("Challenges")
        .onAppear {
            if viewModel == nil {
                viewModel = ChallengesViewModel(context: modelContext)
            }
            // Jeder Aufruf reconciled (nicht nur beim ersten Erscheinen) -
            // das ist genau die Invariante, auf die sich `RankEngine.reconcile`
            // verlässt (siehe dessen Doc-Kommentar).
            rankWelcomeBack = viewModel?.reconcileRankDecayOnAppear()
        }
    }
}

#Preview {
    NavigationStack {
        ChallengesView()
    }
}
