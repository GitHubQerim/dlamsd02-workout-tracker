import SwiftUI
import SwiftData

/// Erstellen/Bearbeiten eines `WorkoutPlan`. Zeigt je nach `ActivityType`
/// ausschließlich die passende Zielfeld-Gruppe (Kraft ODER Cardio) - das ist
/// die strukturelle Durchsetzung der Kraft-/Cardio-Invariante auf UI-Ebene.
struct WorkoutPlanEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: WorkoutPlanEditorViewModel
    @State private var isPresentingExercisePicker = false

    /// `context` wird vom Aufrufer explizit übergeben (aus dessen eigenem
    /// `@Environment(\.modelContext)`) statt hier selbst einen Container zu
    /// erzeugen - `@Environment` steht in `init()` noch nicht zur Verfügung,
    /// und ein View-lokal erzeugter Container widerspräche dem in ADR 0001
    /// festgehaltenen Lifetime-Grundsatz (Views nutzen nur den app-weiten
    /// Container, ViewModels/Views erzeugen nie selbst einen).
    init(context: ModelContext, editing plan: WorkoutPlan? = nil) {
        _viewModel = State(initialValue: WorkoutPlanEditorViewModel(context: context, editing: plan))
    }

    var body: some View {
        NavigationStack {
            DSWashedScreen {
                VStack(alignment: .leading, spacing: DSSpacing.sectionGap) {
                    TextField("Name des Workouts", text: Binding(
                        get: { viewModel.name },
                        set: { viewModel.updateName($0) }
                    ))
                    .font(DSFont.body)
                    .padding(DSSpacing.s12)
                    .background(DSColor.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: DSRadius.card))

                    HStack(spacing: DSSpacing.cardGap) {
                        ForEach(ActivityType.allCases) { type in
                            DSChip(title: type.displayName, active: viewModel.activityType == type) {
                                viewModel.updateActivityType(type)
                            }
                        }
                    }

                    Text("Übungen")
                        .font(DSFont.label)
                        .foregroundStyle(DSColor.textSecondary)

                    List {
                        ForEach(viewModel.drafts) { draft in
                            plannedExerciseRow(draft)
                        }
                        .onDelete { offsets in
                            offsets.forEach { viewModel.removeDraft(id: viewModel.drafts[$0].id) }
                        }
                        .onMove { source, destination in
                            viewModel.moveDrafts(from: source, to: destination)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: CGFloat(viewModel.drafts.count) * 72 + 16)

                    DSButton(title: "Übung hinzufügen", icon: "dumbbell", variant: .outline, fullWidth: true) {
                        isPresentingExercisePicker = true
                    }

                    if let validationMessage = viewModel.validationMessage {
                        Text(validationMessage)
                            .font(DSFont.caption)
                            .foregroundStyle(DSColor.incorrect)
                    }
                }
            }
            .navigationTitle(viewModel.isEditingExistingPlan ? "Workout bearbeiten" : "Neues Workout")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        if viewModel.save() { dismiss() }
                    }
                    .disabled(!viewModel.canSave)
                }
            }
            .sheet(isPresented: $isPresentingExercisePicker) {
                ExercisePickerView { exercise in
                    viewModel.addExercise(exercise)
                }
            }
        }
    }

    @ViewBuilder
    private func plannedExerciseRow(_ draft: WorkoutPlanEditorViewModel.PlannedExerciseDraft) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.s8) {
            Text(draft.exercise.name)
                .font(DSFont.body)
                .foregroundStyle(DSColor.textPrimary)

            if viewModel.activityType.usesSetLogs {
                HStack(spacing: DSSpacing.stackGap) {
                    labeledStepper("Sätze", value: draft.targetSets ?? 3, range: 1...10) { newValue in
                        viewModel.updateStrengthTargets(draftID: draft.id, sets: newValue, reps: draft.targetReps, weightKg: draft.targetWeightKg)
                    }
                    labeledStepper("Wdh.", value: draft.targetReps ?? 10, range: 1...30) { newValue in
                        viewModel.updateStrengthTargets(draftID: draft.id, sets: draft.targetSets, reps: newValue, weightKg: draft.targetWeightKg)
                    }
                }
            } else {
                HStack(spacing: DSSpacing.stackGap) {
                    labeledStepper("Distanz (km)", value: Int((draft.targetDistanceMeters ?? 1000) / 1000), range: 1...100) { newValue in
                        viewModel.updateCardioTargets(draftID: draft.id, distanceMeters: Double(newValue) * 1000, durationSeconds: draft.targetDurationSeconds)
                    }
                }
            }
        }
        .listRowBackground(DSColor.surfaceCard)
    }

    private func labeledStepper(_ label: String, value: Int, range: ClosedRange<Int>, onChange: @escaping (Int) -> Void) -> some View {
        Stepper(value: Binding(get: { value }, set: { onChange($0) }), in: range) {
            Text("\(label): \(value)")
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
        }
    }
}
