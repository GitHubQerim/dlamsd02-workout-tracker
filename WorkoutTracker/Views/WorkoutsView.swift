import SwiftUI
import SwiftData

struct WorkoutsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Workout.createdAt, order: .reverse) private var plans: [Workout]
    @Query(sort: \WorkoutProgram.createdAt, order: .reverse) private var programs: [WorkoutProgram]
    @Query(filter: #Predicate<WorkoutSession> { $0.endDate == nil }) private var openSessions: [WorkoutSession]

    @State private var isPresentingNewPlan = false
    @State private var isPresentingNewProgram = false
    @State private var freeTrainingSessionViewModel: WorkoutSessionViewModel?

    private var hasOpenSession: Bool { !openSessions.isEmpty }

    var body: some View {
        DSWashedScreen {
            VStack(alignment: .leading, spacing: DSSpacing.sectionGap) {
                if let openSession = openSessions.first {
                    openSessionBanner(openSession)
                }

                Text("Deine Pläne")
                    .font(DSFont.label)
                    .foregroundStyle(DSColor.textSecondary)

                DSButton(title: "Plan erstellen", icon: "calendar", fullWidth: true) {
                    isPresentingNewProgram = true
                }
                .disabled(hasOpenSession)

                if !programs.isEmpty {
                    VStack(spacing: DSSpacing.cardGap) {
                        ForEach(programs) { program in
                            NavigationLink {
                                WorkoutProgramDetailView(program: program)
                            } label: {
                                programCard(program)
                            }
                            .buttonStyle(.plain)
                        }
                    }
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
                                WorkoutDetailView(plan: plan)
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
            WorkoutEditorView(context: modelContext)
        }
        .sheet(isPresented: $isPresentingNewProgram) {
            WorkoutProgramEditorView(context: modelContext)
        }
        .fullScreenCover(item: $freeTrainingSessionViewModel) { sessionViewModel in
            WorkoutSessionView(viewModel: sessionViewModel)
        }
    }

    @ViewBuilder
    private func programCard(_ program: WorkoutProgram) -> some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSSpacing.s4) {
                HStack {
                    Text(program.name)
                        .font(DSFont.body)
                        .foregroundStyle(DSColor.textPrimary)
                    if program.isDefault {
                        DSChip(title: "Standard", active: true) {}
                    }
                    Spacer()
                }
                Text("\(program.entries.count) Tage")
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textTertiary)
                if program.isDefault, let next = program.nextEntry(in: modelContext) {
                    Text(next.nextDayDisplayText)
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.accent)
                }
            }
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
