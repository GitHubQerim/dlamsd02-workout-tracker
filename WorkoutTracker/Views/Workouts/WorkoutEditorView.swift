import SwiftUI
import SwiftData

/// Erstellen/Bearbeiten eines `Workout`. Zeigt je nach `ActivityType`
/// ausschließlich die passende Zielfeld-Gruppe (Kraft ODER Cardio) - das ist
/// die strukturelle Durchsetzung der Kraft-/Cardio-Invariante auf UI-Ebene.
struct WorkoutEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: WorkoutEditorViewModel
    @State private var isPresentingExercisePicker = false
    @State private var pendingDraftDeletion: UUID?
    @State private var pendingSegmentDeletion: UUID?

    /// `context` wird vom Aufrufer explizit übergeben (aus dessen eigenem
    /// `@Environment(\.modelContext)`) statt hier selbst einen Container zu
    /// erzeugen - `@Environment` steht in `init()` noch nicht zur Verfügung,
    /// und ein View-lokal erzeugter Container widerspräche dem in ADR 0001
    /// festgehaltenen Lifetime-Grundsatz (Views nutzen nur den app-weiten
    /// Container, ViewModels/Views erzeugen nie selbst einen).
    init(context: ModelContext, editing plan: Workout? = nil) {
        _viewModel = State(initialValue: WorkoutEditorViewModel(context: context, editing: plan))
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

                    Text(viewModel.activityType.usesSetLogs ? "Übungen" : "Segmente")
                        .font(DSFont.label)
                        .foregroundStyle(DSColor.textSecondary)

                    List {
                        if viewModel.activityType.usesSetLogs {
                            ForEach(viewModel.drafts) { draft in
                                plannedExerciseRow(draft)
                            }
                            .onDelete { offsets in
                                pendingDraftDeletion = offsets.first.map { viewModel.drafts[$0].id }
                            }
                            .onMove { source, destination in
                                viewModel.moveDrafts(from: source, to: destination)
                            }
                        } else {
                            ForEach(viewModel.segmentDrafts) { draft in
                                plannedSegmentRow(draft)
                            }
                            .onDelete { offsets in
                                pendingSegmentDeletion = offsets.first.map { viewModel.segmentDrafts[$0].id }
                            }
                            .onMove { source, destination in
                                viewModel.moveSegmentDrafts(from: source, to: destination)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: CGFloat(viewModel.activityType.usesSetLogs ? viewModel.drafts.count : viewModel.segmentDrafts.count) * 72 + 16)

                    if viewModel.activityType.usesSetLogs {
                        DSButton(title: "Übung hinzufügen", icon: "dumbbell", variant: .outline, fullWidth: true) {
                            isPresentingExercisePicker = true
                        }
                    } else {
                        DSButton(title: "Segment hinzufügen", icon: "flame", variant: .outline, fullWidth: true) {
                            viewModel.addSegment()
                        }
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
                ToolbarItemGroup(placement: .topBarLeading) {
                    // `.keyboardShortcut(.cancelAction)` statt der
                    // `.cancellationAction`-Platzierung (die hier keinen
                    // Platz mehr neben `EditButton()` hätte): erhält die
                    // Escape-Taste-Bindung auf iPad/Mac Catalyst, die sonst
                    // mit dem Wechsel auf `.topBarLeading` verloren ginge.
                    Button("Abbrechen") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                    EditButton()
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
            .confirmRemoval(title: "Übung entfernen?", pendingID: $pendingDraftDeletion) { id in
                viewModel.removeDraft(id: id)
            }
            .confirmRemoval(title: "Segment entfernen?", pendingID: $pendingSegmentDeletion) { id in
                viewModel.removeSegmentDraft(id: id)
            }
        }
    }

    @ViewBuilder
    private func plannedExerciseRow(_ draft: WorkoutEditorViewModel.PlannedExerciseDraft) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.s8) {
            Text(draft.exercise.name)
                .font(DSFont.body)
                .foregroundStyle(DSColor.textPrimary)

            HStack(spacing: DSSpacing.stackGap) {
                labeledStepper("Sätze", value: draft.targetSets ?? WorkoutEditorViewModel.defaultTargetSets, range: 1...10) { newValue in
                    viewModel.updateStrengthTargets(draftID: draft.id, sets: newValue, reps: draft.targetReps, weightKg: draft.targetWeightKg)
                }
                DSWheelPickerField(
                    label: "Wdh.",
                    value: draft.targetReps ?? WorkoutEditorViewModel.defaultTargetReps,
                    options: Array(1...30),
                    displayText: { "\($0)" }
                ) { newValue in
                    viewModel.updateStrengthTargets(draftID: draft.id, sets: draft.targetSets, reps: newValue, weightKg: draft.targetWeightKg)
                }
            }
        }
        .listRowBackground(DSColor.surfaceCard)
    }

    @ViewBuilder
    private func plannedSegmentRow(_ draft: WorkoutEditorViewModel.PlannedSegmentDraft) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.s8) {
            TextField("Bezeichnung", text: Binding(
                get: { draft.label },
                set: { viewModel.updateSegmentLabel(id: draft.id, $0) }
            ))
            .font(DSFont.body)
            .foregroundStyle(DSColor.textPrimary)

            HStack(spacing: DSSpacing.stackGap) {
                if let fieldOptions = viewModel.activityType.cardioFieldOptions, fieldOptions.showsDistance {
                    labeledStepper("Distanz (km)", value: Int((draft.targetDistanceMeters ?? 1000) / 1000), range: 1...100) { newValue in
                        viewModel.updateSegmentTargets(id: draft.id, distanceMeters: Double(newValue) * 1000, durationSeconds: draft.targetDurationSeconds)
                    }
                }
                if let fieldOptions = viewModel.activityType.cardioFieldOptions, fieldOptions.showsDuration {
                    DSWheelPickerField(
                        label: "Dauer (Min.)",
                        value: Int((draft.targetDurationSeconds ?? 600) / 60),
                        options: Array(1...180),
                        displayText: { "\($0)" }
                    ) { newValue in
                        viewModel.updateSegmentTargets(id: draft.id, distanceMeters: draft.targetDistanceMeters, durationSeconds: Double(newValue) * 60)
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
