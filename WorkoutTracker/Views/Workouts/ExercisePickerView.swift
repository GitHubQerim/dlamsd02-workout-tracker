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
    /// Schränkt die Auswahl auf einen bekannten Namens-Pool ein (z.B. die
    /// übrigen Übungen desselben Plans für die Superset-Partnerwahl) statt
    /// des vollen Katalogs. `nil` (Default) hält das bestehende Verhalten
    /// für "Übung hinzufügen" unverändert. Bei aktiver Einschränkung ergibt
    /// "Eigene Übung anlegen" keinen Sinn (die neue Übung wäre nie Teil des
    /// erlaubten Pools) und wird ausgeblendet.
    var allowedExerciseNames: Set<String>? = nil

    @State private var selectedMuscleGroup: MuscleGroup?
    @State private var isPresentingNewExercise = false
    @State private var newExerciseName = ""
    @State private var newExerciseMuscleGroup: MuscleGroup = .ganzkoerper
    @State private var newExerciseValidationMessage: String?

    private var filteredExercises: [Exercise] {
        let scoped = allowedExerciseNames.map { names in exercises.filter { names.contains($0.name) } } ?? exercises
        guard let selectedMuscleGroup else { return scoped }
        return scoped.filter { $0.muscleGroup == selectedMuscleGroup }
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

                    if allowedExerciseNames == nil {
                        DSButton(title: "Eigene Übung anlegen", icon: "info", variant: .outline, fullWidth: true) {
                            isPresentingNewExercise = true
                        }
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
                if let newExerciseValidationMessage {
                    Text(newExerciseValidationMessage)
                        .foregroundStyle(DSColor.incorrect)
                }
            }
            .navigationTitle("Eigene Übung")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { isPresentingNewExercise = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Anlegen") { createCustomExercise() }
                        .disabled(newExerciseName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    /// `Exercise.name` ist im Datenmodell `@Attribute(.unique)`. Legt man
    /// hier ungeprüft eine zweite Übung mit demselben Namen an, scheitert
    /// entweder dieser Save (harmlos) oder - schlimmer - ein *späterer*,
    /// scheinbar unabhängiger Save andernorts, weil das ungültige Objekt im
    /// Context hängen bleibt. Deshalb: vorher explizit gegen den
    /// bestehenden Katalog (case-insensitive) prüfen, bei Treffer die
    /// vorhandene Übung auswählen statt eine zweite anzulegen.
    private func createCustomExercise() {
        let trimmedName = newExerciseName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        if let existing = exercises.first(where: { $0.name.localizedCaseInsensitiveCompare(trimmedName) == .orderedSame }) {
            isPresentingNewExercise = false
            onSelect(existing)
            dismiss()
            return
        }

        let exercise = Exercise(name: trimmedName, muscleGroup: newExerciseMuscleGroup, isCustom: true)
        modelContext.insert(exercise)
        do {
            try modelContext.save()
        } catch {
            modelContext.delete(exercise)
            newExerciseValidationMessage = "Anlegen fehlgeschlagen: \(error.localizedDescription)"
            return
        }
        newExerciseValidationMessage = nil
        isPresentingNewExercise = false
        onSelect(exercise)
        dismiss()
    }
}
