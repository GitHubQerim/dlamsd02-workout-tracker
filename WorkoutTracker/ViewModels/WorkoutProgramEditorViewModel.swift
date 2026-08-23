import Foundation
import SwiftData

/// Bearbeitet ein `WorkoutProgram` über Drafts statt Live-Mutation der
/// `@Model`-Objekte - gleiches Muster wie `WorkoutEditorViewModel`, nur dass
/// hier bestehende `Workout`s zu Tagen verbunden statt Übungen angelegt
/// werden.
@Observable
@MainActor
final class WorkoutProgramEditorViewModel {
    struct ProgramEntryDraft: Identifiable {
        let id: UUID
        var dayLabel: String
        var workout: Workout
        /// nil, wenn der Tag in dieser Editier-Sitzung neu hinzugefügt wurde.
        var existing: WorkoutProgramEntry?
    }

    private(set) var name: String = ""
    private(set) var isDefault: Bool = false
    private(set) var drafts: [ProgramEntryDraft] = []
    private(set) var validationMessage: String?

    private let existingProgram: WorkoutProgram?
    private let context: ModelContext

    var isEditingExistingProgram: Bool { existingProgram != nil }
    var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && !drafts.isEmpty }

    init(context: ModelContext, editing program: WorkoutProgram? = nil) {
        self.context = context
        self.existingProgram = program
        guard let program else { return }
        name = program.name
        isDefault = program.isDefault
        drafts = program.entries
            .sorted { $0.orderIndex < $1.orderIndex }
            .compactMap { entry in
                // Workout wurde inzwischen gelöscht (nullify) - kann in
                // dieser Editier-Sitzung nicht mehr sinnvoll dargestellt
                // werden (kein Workout zum Neu-Zuweisen einer Zeile).
                guard let workout = entry.workout else { return nil }
                return ProgramEntryDraft(id: UUID(), dayLabel: entry.dayLabel, workout: workout, existing: entry)
            }
    }

    func updateName(_ newValue: String) {
        name = newValue
    }

    func updateIsDefault(_ newValue: Bool) {
        isDefault = newValue
    }

    func addEntry(workout: Workout) {
        drafts.append(ProgramEntryDraft(id: UUID(), dayLabel: "Day \(drafts.count + 1)", workout: workout, existing: nil))
    }

    func updateDayLabel(draftID: UUID, label: String) {
        guard let index = drafts.firstIndex(where: { $0.id == draftID }) else { return }
        drafts[index].dayLabel = label
    }

    func removeDraft(id: UUID) {
        drafts.removeAll { $0.id == id }
    }

    func moveDrafts(from source: IndexSet, to destination: Int) {
        drafts.move(fromOffsets: source, toOffset: destination)
    }

    @discardableResult
    func save() -> Bool {
        guard canSave else {
            validationMessage = "Name und mindestens ein Tag sind erforderlich."
            return false
        }

        let program = existingProgram ?? WorkoutProgram(name: name)
        program.name = name
        if existingProgram == nil {
            context.insert(program)
        }

        let keepIDs = Set(drafts.compactMap { $0.existing?.persistentModelID })
        for entry in program.entries where !keepIDs.contains(entry.persistentModelID) {
            context.delete(entry)
        }

        for (index, draft) in drafts.enumerated() {
            if let existing = draft.existing {
                existing.orderIndex = index
                existing.dayLabel = draft.dayLabel
                existing.workout = draft.workout
                existing.workoutName = draft.workout.name
            } else {
                let entry = WorkoutProgramEntry(orderIndex: index, dayLabel: draft.dayLabel, workout: draft.workout)
                entry.program = program
                context.insert(entry)
            }
        }

        if isDefault {
            Self.setDefault(program, in: context)
        } else {
            program.isDefault = false
        }

        do {
            try context.save()
            Self.assertAtMostOneDefault(in: context)
            WidgetSnapshotRefresher.refresh(context: context)
            return true
        } catch {
            validationMessage = "Speichern fehlgeschlagen: \(error.localizedDescription)"
            return false
        }
    }

    /// Setzt `program` als Standard und alle anderen zurück - der einzige Ort,
    /// an dem die Default-Invariante durchgesetzt wird (reine ViewModel-
    /// Invariante, keine DB-Constraint, gleiches Muster wie die Kraft-/
    /// Cardio-Feld-Invariante in `WorkoutEditorViewModel.updateActivityType`).
    /// Speichert bewusst NICHT selbst - Aufrufer (Editor-`save()` oder ein
    /// Quick-Toggle außerhalb des Editors) entscheiden, wann genau einmal
    /// gespeichert wird.
    static func setDefault(_ program: WorkoutProgram, in context: ModelContext) {
        let others = (try? context.fetch(FetchDescriptor<WorkoutProgram>())) ?? []
        for other in others where other.persistentModelID != program.persistentModelID {
            other.isDefault = false
        }
        program.isDefault = true
    }

    /// Quick-Toggle für "Als Standard festlegen" außerhalb des vollen Editors
    /// (z.B. direkt auf der Plan-Detailseite) - nutzt denselben Invarianten-
    /// Helper, speichert aber selbst, da hier kein umgebender Save-Vorgang
    /// existiert.
    static func setAsDefaultAndSave(_ program: WorkoutProgram, in context: ModelContext) {
        setDefault(program, in: context)
        try? context.save()
        assertAtMostOneDefault(in: context)
        WidgetSnapshotRefresher.refresh(context: context)
    }

    private static func assertAtMostOneDefault(in context: ModelContext) {
        assert(
            ((try? context.fetchCount(FetchDescriptor<WorkoutProgram>(
                predicate: #Predicate { $0.isDefault == true }
            ))) ?? 0) <= 1,
            "Es darf höchstens ein Standard-Programm geben"
        )
    }
}
