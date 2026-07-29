import SwiftUI
import SwiftData

/// Start-Screen: zeigt den aktuellen Trainingsstatus (Aufgabenstellung 3's
/// mandatory Start-Screen-Anforderung, hier auf Workout-Ebene UND - seit
/// Phase D - mit dem Fortschritt der ersten beigetretenen Challenge).
struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.startDate, order: .reverse) private var sessions: [WorkoutSession]
    @Query(filter: #Predicate<WorkoutSession> { $0.endDate == nil }) private var openSessions: [WorkoutSession]
    @Query(filter: #Predicate<WorkoutProgram> { $0.isDefault == true }) private var defaultPrograms: [WorkoutProgram]
    @Query(sort: \Challenge.name) private var challenges: [Challenge]

    @State private var resumedSessionViewModel: WorkoutSessionViewModel?

    private var firstEnrolledChallenge: Challenge? {
        challenges.first { !$0.enrollments.isEmpty }
    }

    private func challengeProgress(_ challenge: Challenge) -> Int {
        switch challenge.challengeType {
        case .streakTage:
            ChallengeInsights.currentStreakDays(entries: challenge.progressEntries)
        case .frequenzProWoche:
            ChallengeInsights.weeklyProgress(entries: challenge.progressEntries)
        }
    }

    private var completedSessions: [WorkoutSession] {
        sessions.filter { $0.endDate != nil }
    }

    private var sessionsThisWeek: Int {
        let calendar = Calendar.current
        return completedSessions.filter {
            calendar.isDate($0.startDate, equalTo: .now, toGranularity: .weekOfYear)
        }.count
    }

    /// Zeigt Programm-Tag + Programmname, sofern die Session aus einem
    /// WorkoutProgram gestartet wurde, sonst wie bisher nur die Sportart.
    private func lastTrainingDisplayText(for session: WorkoutSession) -> String {
        guard let programDayLabel = session.programDayLabel, let programName = session.programName else {
            return session.activityType.displayName
        }
        return "\(programDayLabel) · \(programName)"
    }

    var body: some View {
        DSWashedScreen {
            VStack(alignment: .leading, spacing: DSSpacing.sectionGap) {
                if let openSession = openSessions.first {
                    DSCard(borderColor: DSColor.accent) {
                        HStack {
                            VStack(alignment: .leading, spacing: DSSpacing.s4) {
                                Text("Training läuft")
                                    .font(DSFont.label)
                                    .foregroundStyle(DSColor.accent)
                                Text(openSession.activityType.displayName)
                                    .font(DSFont.body)
                                    .foregroundStyle(DSColor.textPrimary)
                            }
                            Spacer()
                            DSButton(title: "Fortsetzen", variant: .outline) {
                                resumedSessionViewModel = WorkoutSessionViewModel(context: modelContext, session: openSession)
                            }
                        }
                    }
                }

                HStack(spacing: DSSpacing.cardGap) {
                    DSStatTile(label: "Diese Woche", icon: "chart-column", value: "\(sessionsThisWeek)")
                    if let lastSession = completedSessions.first {
                        DSStatTile(label: "Letztes Training", icon: "flame", value: lastTrainingDisplayText(for: lastSession))
                    } else {
                        DSStatTile(label: "Letztes Training", icon: "flame", value: "-")
                    }
                }

                if let challenge = firstEnrolledChallenge {
                    DSCard {
                        HStack {
                            VStack(alignment: .leading, spacing: DSSpacing.s4) {
                                Text(challenge.name)
                                    .font(DSFont.label)
                                    .foregroundStyle(DSColor.textSecondary)
                                Text("\(challengeProgress(challenge)) / \(challenge.targetValue)")
                                    .font(DSFont.body)
                                    .foregroundStyle(DSColor.textPrimary)
                            }
                            Spacer()
                        }
                    }
                }

                if let defaultProgram = defaultPrograms.first, let nextEntry = defaultProgram.nextEntry(in: modelContext) {
                    DSCard {
                        HStack {
                            VStack(alignment: .leading, spacing: DSSpacing.s4) {
                                Text(defaultProgram.name)
                                    .font(DSFont.label)
                                    .foregroundStyle(DSColor.textSecondary)
                                Text(nextEntry.nextDayDisplayText)
                                    .font(DSFont.body)
                                    .foregroundStyle(DSColor.textPrimary)
                            }
                            Spacer()
                            DSButton(title: "Starten", variant: .outline) {
                                resumedSessionViewModel = WorkoutSessionViewModel.start(
                                    context: modelContext,
                                    programEntry: nextEntry,
                                    programName: defaultProgram.name
                                )
                            }
                            .disabled(!openSessions.isEmpty || nextEntry.workout == nil)
                        }
                    }
                }

                if completedSessions.isEmpty {
                    DSCard {
                        VStack(alignment: .leading, spacing: DSSpacing.stackGap) {
                            Text("Noch kein Training protokolliert")
                                .font(DSFont.body)
                                .foregroundStyle(DSColor.textPrimary)
                            Text("Leg im Workouts-Tab dein erstes Training an.")
                                .font(DSFont.caption)
                                .foregroundStyle(DSColor.textSecondary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Dashboard")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Einstellungen")
            }
        }
        .fullScreenCover(item: $resumedSessionViewModel) { sessionViewModel in
            WorkoutSessionView(viewModel: sessionViewModel)
        }
    }
}

#Preview {
    NavigationStack {
        DashboardView()
    }
}
