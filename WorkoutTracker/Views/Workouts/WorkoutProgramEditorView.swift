import SwiftUI
import SwiftData

/// Erstellen/Bearbeiten eines `WorkoutProgram`: Name, Reihenfolge der
/// verbundenen `Workout`-Tage, und ob dieses Programm der Standard-Plan ist.
struct WorkoutProgramEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: WorkoutProgramEditorViewModel
    @State private var isPresentingWorkoutPicker = false
    @State private var pendingEntryDeletion: UUID?

    init(context: ModelContext, editing program: WorkoutProgram? = nil) {
        _viewModel = State(initialValue: WorkoutProgramEditorViewModel(context: context, editing: program))
    }

    var body: some View {
        NavigationStack {
            DSWashedScreen {
                VStack(alignment: .leading, spacing: DSSpacing.sectionGap) {
                    TextField("Name des Plans", text: Binding(
                        get: { viewModel.name },
                        set: { viewModel.updateName($0) }
                    ))
                    .font(DSFont.body)
                    .padding(DSSpacing.s12)
                    .background(DSColor.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: DSRadius.card))

                    Toggle("Als Standard-Plan", isOn: Binding(
                        get: { viewModel.isDefault },
                        set: { viewModel.updateIsDefault($0) }
                    ))
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.textPrimary)

                    Text("Tage")
                        .font(DSFont.label)
                        .foregroundStyle(DSColor.textSecondary)

                    List {
                        ForEach(viewModel.drafts) { draft in
                            entryRow(draft)
                        }
                        .onDelete { offsets in
                            pendingEntryDeletion = offsets.first.map { viewModel.drafts[$0].id }
                        }
                        .onMove { source, destination in
                            viewModel.moveDrafts(from: source, to: destination)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: CGFloat(viewModel.drafts.count) * 72 + 16)

                    DSButton(title: "Workout hinzufügen", icon: "dumbbell", variant: .outline, fullWidth: true) {
                        isPresentingWorkoutPicker = true
                    }

                    if let validationMessage = viewModel.validationMessage {
                        Text(validationMessage)
                            .font(DSFont.caption)
                            .foregroundStyle(DSColor.incorrect)
                    }
                }
            }
            .navigationTitle(viewModel.isEditingExistingProgram ? "Plan bearbeiten" : "Neuer Plan")
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    // Siehe Kommentar in WorkoutEditorView.swift - erhält die
                    // Escape-Taste-Bindung auf iPad/Mac Catalyst.
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
            .sheet(isPresented: $isPresentingWorkoutPicker) {
                WorkoutPickerView { workout in
                    viewModel.addEntry(workout: workout)
                }
            }
            .confirmRemoval(title: "Tag entfernen?", pendingID: $pendingEntryDeletion) { id in
                viewModel.removeDraft(id: id)
            }
        }
    }

    @ViewBuilder
    private func entryRow(_ draft: WorkoutProgramEditorViewModel.ProgramEntryDraft) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.s8) {
            TextField("Tag-Label", text: Binding(
                get: { draft.dayLabel },
                set: { viewModel.updateDayLabel(draftID: draft.id, label: $0) }
            ))
            .font(DSFont.body)
            .foregroundStyle(DSColor.textPrimary)

            Text(draft.workout.name)
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
        }
        .listRowBackground(DSColor.surfaceCard)
    }
}
