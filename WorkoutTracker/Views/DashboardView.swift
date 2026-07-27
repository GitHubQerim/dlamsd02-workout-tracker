import SwiftUI
import SwiftData

/// Start-Screen: zeigt den aktuellen Trainingsstatus (Aufgabenstellung 3's
/// mandatory Start-Screen-Anforderung, hier auf Workout-Ebene - die
/// Challenge-spezifische Statusanzeige kommt mit Phase D dazu).
struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.startDate, order: .reverse) private var sessions: [WorkoutSession]
    @Query(filter: #Predicate<WorkoutSession> { $0.endDate == nil }) private var openSessions: [WorkoutSession]

    @State private var resumedSessionViewModel: WorkoutSessionViewModel?

    private var completedSessions: [WorkoutSession] {
        sessions.filter { $0.endDate != nil }
    }

    private var sessionsThisWeek: Int {
        let calendar = Calendar.current
        return completedSessions.filter {
            calendar.isDate($0.startDate, equalTo: .now, toGranularity: .weekOfYear)
        }.count
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
                        DSStatTile(label: "Letztes Training", icon: "flame", value: lastSession.activityType.displayName)
                    } else {
                        DSStatTile(label: "Letztes Training", icon: "flame", value: "-")
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
