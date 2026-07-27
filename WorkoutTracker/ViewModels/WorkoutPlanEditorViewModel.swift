import Foundation
import SwiftData

/// Bearbeitet einen `WorkoutPlan` über Drafts statt Live-Mutation der
/// `@Model`-Objekte, damit "Abbrechen" ohne Teil-Speicherungen möglich ist
/// und die Kraft-/Cardio-Invariante an einer Stelle (`updateActivityType`)
/// statt verstreut in der View durchgesetzt werden kann.
@Observable
@MainActor
final class WorkoutPlanEditorViewModel {
    struct PlannedExerciseDraft: Identifiable {
        let id: UUID
        var exercise: Exercise
        var targetSets: Int?
        var targetReps: Int?
        var targetWeightKg: Double?
        var targetDistanceMeters: Double?
        var targetDurationSeconds: Double?
        /// nil, wenn die Übung in dieser Editier-Sitzung neu hinzugefügt wurde.
        var existing: PlannedExercise?
    }

    private(set) var name: String = ""
    private(set) var activityType: ActivityType = .kraft
    private(set) var drafts: [PlannedExerciseDraft] = []
    private(set) var validationMessage: String?

    private let existingPlan: WorkoutPlan?
    private let context: ModelContext

    var isEditingExistingPlan: Bool { existingPlan != nil }
    var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && !drafts.isEmpty }

    init(context: ModelContext, editing plan: WorkoutPlan? = nil) {
        self.context = context
        self.existingPlan = plan
        guard let plan else { return }
        name = plan.name
        activityType = plan.activityType
        drafts = plan.plannedExercises
            .sorted { $0.orderIndex < $1.orderIndex }
            .compactMap { plannedExercise in
                // Übung wurde inzwischen aus dem Katalog gelöscht (nullify) -
                // kann in dieser Editier-Sitzung nicht mehr sinnvoll dargestellt werden.
                guard let exercise = plannedExercise.exercise else { return nil }
                return PlannedExerciseDraft(
                    id: UUID(),
                    exercise: exercise,
                    targetSets: plannedExercise.targetSets,
                    targetReps: plannedExercise.targetReps,
                    targetWeightKg: plannedExercise.targetWeightKg,
                    targetDistanceMeters: plannedExercise.targetDistanceMeters,
                    targetDurationSeconds: plannedExercise.targetDurationSeconds,
                    existing: plannedExercise
                )
            }
    }

    func updateName(_ newValue: String) {
        name = newValue
    }

    /// Zentrale Stelle für die Kraft-/Cardio-Invariante: beim Sportart-Wechsel
    /// werden die jeweils unpassenden Zielfelder aller Drafts geleert, damit
    /// nie beide Feldgruppen gleichzeitig befüllt sein können.
    func updateActivityType(_ newValue: ActivityType) {
        activityType = newValue
        for index in drafts.indices {
            if newValue.usesSetLogs {
                drafts[index].targetDistanceMeters = nil
                drafts[index].targetDurationSeconds = nil
            } else {
                drafts[index].targetSets = nil
                drafts[index].targetReps = nil
                drafts[index].targetWeightKg = nil
            }
        }
    }

    func addExercise(_ exercise: Exercise) {
        drafts.append(PlannedExerciseDraft(id: UUID(), exercise: exercise, existing: nil))
    }

    func removeDraft(id: UUID) {
        drafts.removeAll { $0.id == id }
    }

    func moveDrafts(from source: IndexSet, to destination: Int) {
        drafts.move(fromOffsets: source, toOffset: destination)
    }

    func updateStrengthTargets(draftID: UUID, sets: Int?, reps: Int?, weightKg: Double?) {
        guard let index = drafts.firstIndex(where: { $0.id == draftID }) else { return }
        drafts[index].targetSets = sets
        drafts[index].targetReps = reps
        drafts[index].targetWeightKg = weightKg
    }

    func updateCardioTargets(draftID: UUID, distanceMeters: Double?, durationSeconds: Double?) {
        guard let index = drafts.firstIndex(where: { $0.id == draftID }) else { return }
        drafts[index].targetDistanceMeters = distanceMeters
        drafts[index].targetDurationSeconds = durationSeconds
    }

    @discardableResult
    func save() -> Bool {
        guard canSave else {
            validationMessage = "Name und mindestens eine Übung sind erforderlich."
            return false
        }

        let plan = existingPlan ?? WorkoutPlan(name: name, activityType: activityType)
        plan.name = name
        plan.activityType = activityType
        if existingPlan == nil {
            context.insert(plan)
        }

        let keepIDs = Set(drafts.compactMap { $0.existing?.persistentModelID })
        for plannedExercise in plan.plannedExercises where !keepIDs.contains(plannedExercise.persistentModelID) {
            context.delete(plannedExercise)
        }

        for (index, draft) in drafts.enumerated() {
            if let existing = draft.existing {
                existing.orderIndex = index
                existing.targetSets = draft.targetSets
                existing.targetReps = draft.targetReps
                existing.targetWeightKg = draft.targetWeightKg
                existing.targetDistanceMeters = draft.targetDistanceMeters
                existing.targetDurationSeconds = draft.targetDurationSeconds
            } else {
                let plannedExercise = PlannedExercise(
                    orderIndex: index,
                    exercise: draft.exercise,
                    targetSets: draft.targetSets,
                    targetReps: draft.targetReps,
                    targetWeightKg: draft.targetWeightKg,
                    targetDistanceMeters: draft.targetDistanceMeters,
                    targetDurationSeconds: draft.targetDurationSeconds
                )
                plannedExercise.plan = plan
                context.insert(plannedExercise)
            }
        }

        assert(
            drafts.allSatisfy { draft in
                let hasStrengthFields = draft.targetSets != nil || draft.targetReps != nil || draft.targetWeightKg != nil
                let hasCardioFields = draft.targetDistanceMeters != nil || draft.targetDurationSeconds != nil
                return !(hasStrengthFields && hasCardioFields)
            },
            "Kraft- und Cardio-Zielfelder dürfen nie gleichzeitig befüllt sein"
        )

        do {
            try context.save()
            return true
        } catch {
            validationMessage = "Speichern fehlgeschlagen: \(error.localizedDescription)"
            return false
        }
    }
}
