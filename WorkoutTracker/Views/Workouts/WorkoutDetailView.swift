import SwiftUI
import SwiftData

/// Read-only Übersicht eines `Workout` mit den Aktionen "Bearbeiten"
/// und "Training starten".
struct WorkoutDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<WorkoutSession> { $0.endDate == nil }) private var openSessions: [WorkoutSession]
    let plan: Workout

    @State private var isPresentingEditor = false
    @State private var activeSessionViewModel: WorkoutSessionViewModel?

    var body: some View {
        DSWashedScreen {
            VStack(alignment: .leading, spacing: DSSpacing.sectionGap) {
                Text(plan.name)
                    .font(DSFont.screenTitle)
                    .foregroundStyle(DSColor.textPrimary)

                DSChip(title: plan.activityType.displayName, active: true) {}

                VStack(spacing: DSSpacing.cardGap) {
                    if plan.activityType.usesSetLogs {
                        ForEach(plan.plannedExercises.sorted(by: { $0.orderIndex < $1.orderIndex })) { plannedExercise in
                            DSCard {
                                HStack {
                                    Text(plannedExercise.exerciseName)
                                        .font(DSFont.body)
                                        .foregroundStyle(DSColor.textPrimary)
                                    Spacer()
                                    Text("\(plannedExercise.targetSets ?? WorkoutEditorViewModel.defaultTargetSets) × \(plannedExercise.targetReps ?? WorkoutEditorViewModel.defaultTargetReps)")
                                        .font(DSFont.caption)
                                        .foregroundStyle(DSColor.textSecondary)
                                }
                            }
                        }
                    } else {
                        ForEach(plan.segments.sorted(by: { $0.orderIndex < $1.orderIndex })) { segment in
                            DSCard {
                                HStack {
                                    Text(segment.label)
                                        .font(DSFont.body)
                                        .foregroundStyle(DSColor.textPrimary)
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: DSSpacing.s4) {
                                        if let distance = segment.targetDistanceMeters {
                                            Text("\(Int(distance / 1000)) km")
                                                .font(DSFont.caption)
                                                .foregroundStyle(DSColor.textSecondary)
                                        }
                                        if let duration = segment.targetDurationSeconds {
                                            Text("\(Int(duration / 60)) Min.")
                                                .font(DSFont.caption)
                                                .foregroundStyle(DSColor.textSecondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                DSButton(title: "Bearbeiten", variant: .outline, fullWidth: true) {
                    isPresentingEditor = true
                }

                DSButton(title: "Training starten", fullWidth: true) {
                    activeSessionViewModel = WorkoutSessionViewModel.start(
                        context: modelContext,
                        plan: plan,
                        activityType: plan.activityType
                    )
                }
                .disabled(!openSessions.isEmpty)

                if !openSessions.isEmpty {
                    Text("Es läuft bereits ein Training - erst dort beenden oder abbrechen.")
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textTertiary)
                }
            }
        }
        .navigationTitle("Workout")
        .sheet(isPresented: $isPresentingEditor) {
            WorkoutEditorView(context: modelContext, editing: plan)
        }
        .fullScreenCover(item: $activeSessionViewModel) { sessionViewModel in
            WorkoutSessionView(viewModel: sessionViewModel)
        }
    }
}
