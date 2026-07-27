import SwiftUI
import SwiftData

struct WorkoutsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutPlan.createdAt, order: .reverse) private var plans: [WorkoutPlan]
    @Query(filter: #Predicate<WorkoutSession> { $0.endDate == nil }) private var openSessions: [WorkoutSession]

    @State private var isPresentingNewPlan = false
    @State private var freeTrainingSessionViewModel: WorkoutSessionViewModel?

    private var hasOpenSession: Bool { !openSessions.isEmpty }

    var body: some View {
        DSWashedScreen {
            VStack(alignment: .leading, spacing: DSSpacing.sectionGap) {
                if let openSession = openSessions.first {
                    openSessionBanner(openSession)
                }

                DSButton(title: "Neues Workout", icon: "dumbbell", fullWidth: true) {
                    isPresentingNewPlan = true
                }
                .disabled(hasOpenSession)

                if plans.isEmpty {
                    Text("Noch keine Workouts angelegt")
                        .font(DSFont.body)
                        .foregroundStyle(DSColor.textSecondary)
                } else {
                    VStack(spacing: DSSpacing.cardGap) {
                        ForEach(plans) { plan in
                            NavigationLink {
                                WorkoutPlanDetailView(plan: plan)
                            } label: {
                                DSCard {
                                    HStack {
                                        VStack(alignment: .leading, spacing: DSSpacing.s4) {
                                            Text(plan.name)
                                                .font(DSFont.body)
                                                .foregroundStyle(DSColor.textPrimary)
                                            Text(plan.activityType.displayName)
                                                .font(DSFont.caption)
                                                .foregroundStyle(DSColor.textTertiary)
                                        }
                                        Spacer()
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Text("Freies Training")
                    .font(DSFont.label)
                    .foregroundStyle(DSColor.textSecondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DSSpacing.cardGap) {
                        ForEach(ActivityType.allCases) { type in
                            DSChip(title: type.displayName, icon: "flame") {
                                freeTrainingSessionViewModel = WorkoutSessionViewModel.start(
                                    context: modelContext,
                                    plan: nil,
                                    activityType: type
                                )
                            }
                        }
                    }
                }
                .disabled(hasOpenSession)
            }
        }
        .navigationTitle("Workouts")
        .sheet(isPresented: $isPresentingNewPlan) {
            WorkoutPlanEditorView(context: modelContext)
        }
        .fullScreenCover(item: $freeTrainingSessionViewModel) { sessionViewModel in
            WorkoutSessionView(viewModel: sessionViewModel)
        }
    }

    @ViewBuilder
    private func openSessionBanner(_ session: WorkoutSession) -> some View {
        DSCard(borderColor: DSColor.accent) {
            HStack {
                VStack(alignment: .leading, spacing: DSSpacing.s4) {
                    Text("Training läuft")
                        .font(DSFont.label)
                        .foregroundStyle(DSColor.accent)
                    Text(session.activityType.displayName)
                        .font(DSFont.body)
                        .foregroundStyle(DSColor.textPrimary)
                }
                Spacer()
                DSButton(title: "Fortsetzen", variant: .outline) {
                    freeTrainingSessionViewModel = WorkoutSessionViewModel(context: modelContext, session: session)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        WorkoutsView()
    }
}
