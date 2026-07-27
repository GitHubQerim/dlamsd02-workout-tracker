import SwiftUI
import SwiftData

/// Sheet-in-Sheet zur Übungsauswahl fürs Workout-Editing. Deckt über das
/// Mini-Formular "Eigene Übung anlegen" auch Cardio-Katalogeinträge ab
/// (z.B. "5 km Lauf" als `Exercise` mit `isCustom: true`).
struct ExercisePickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    let onSelect: (Exercise) -> Void

    @State private var selectedMuscleGroup: MuscleGroup?
    @State private var isPresentingNewExercise = false
    @State private var newExerciseName = ""
    @State private var newExerciseMuscleGroup: MuscleGroup = .ganzkoerper

    private var filteredExercises: [Exercise] {
        guard let selectedMuscleGroup else { return exercises }
        return exercises.filter { $0.muscleGroup == selectedMuscleGroup }
    }

    var body: some View {
        NavigationStack {
            DSWashedScreen {
                VStack(alignment: .leading, spacing: DSSpacing.sectionGap) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DSSpacing.cardGap) {
                            DSChip(title: "Alle", active: selectedMuscleGroup == nil) {
                                selectedMuscleGroup = nil
                            }
                            ForEach(MuscleGroup.allCases) { group in
                                DSChip(title: group.displayName, active: selectedMuscleGroup == group) {
                                    selectedMuscleGroup = group
                                }
                            }
                        }
                    }

                    VStack(spacing: DSSpacing.cardGap) {
                        ForEach(filteredExercises) { exercise in
                            Button {
                                onSelect(exercise)
                                dismiss()
                            } label: {
                                DSCard {
                                    HStack {
                                        VStack(alignment: .leading, spacing: DSSpacing.s4) {
                                            Text(exercise.name)
                                                .font(DSFont.body)
                                                .foregroundStyle(DSColor.textPrimary)
                                            if let muscleGroup = exercise.muscleGroup {
                                                Text(muscleGroup.displayName)
                                                    .font(DSFont.caption)
                                                    .foregroundStyle(DSColor.textTertiary)
                                            }
                                        }
                                        Spacer()
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    DSButton(title: "Eigene Übung anlegen", icon: "info", variant: .outline, fullWidth: true) {
                        isPresentingNewExercise = true
                    }
                }
            }
            .navigationTitle("Übung wählen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
            .sheet(isPresented: $isPresentingNewExercise) {
                newExerciseSheet
            }
        }
    }

    private var newExerciseSheet: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("z.B. 5 km Lauf", text: $newExerciseName)
                }
                Section("Muskelgruppe") {
                    Picker("Muskelgruppe", selection: $newExerciseMuscleGroup) {
                        ForEach(MuscleGroup.allCases) { group in
                            Text(group.displayName).tag(group)
                        }
                    }
                }
            }
            .navigationTitle("Eigene Übung")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { isPresentingNewExercise = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Anlegen") {
                        let trimmedName = newExerciseName.trimmingCharacters(in: .whitespaces)
                        guard !trimmedName.isEmpty else { return }
                        let exercise = Exercise(name: trimmedName, muscleGroup: newExerciseMuscleGroup, isCustom: true)
                        modelContext.insert(exercise)
                        try? modelContext.save()
                        isPresentingNewExercise = false
                        onSelect(exercise)
                        dismiss()
                    }
                    .disabled(newExerciseName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
