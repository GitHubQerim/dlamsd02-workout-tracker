import Foundation
import SwiftData

/// Bearbeitet einen `Workout` über Drafts statt Live-Mutation der
/// `@Model`-Objekte, damit "Abbrechen" ohne Teil-Speicherungen möglich ist
/// und die Kraft-/Cardio-Invariante an einer Stelle (`updateActivityType`)
/// statt verstreut in der View durchgesetzt werden kann.
@Observable
@MainActor
final class WorkoutEditorViewModel {
    struct PlannedExerciseDraft: Identifiable {
        let id: UUID
        var exercise: Exercise
        var targetSets: Int?
        var targetReps: Int?
        var targetWeightKg: Double?
        /// nil, wenn die Übung in dieser Editier-Sitzung neu hinzugefügt wurde.
        var existing: PlannedExercise?
    }

    struct PlannedSegmentDraft: Identifiable {
        let id: UUID
        var label: String
        var targetDistanceMeters: Double?
        var targetDurationSeconds: Double?
        /// nil, wenn das Segment in dieser Editier-Sitzung neu hinzugefügt wurde.
        var existing: PlannedSegment?
    }

    private(set) var name: String = ""
    private(set) var activityType: ActivityType = .kraft
    private(set) var drafts: [PlannedExerciseDraft] = []
    private(set) var segmentDrafts: [PlannedSegmentDraft] = []
    private(set) var validationMessage: String?

    private let existingPlan: Workout?
    private let context: ModelContext

    var isEditingExistingPlan: Bool { existingPlan != nil }
    var canSave: Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        return activityType.usesSetLogs ? !drafts.isEmpty : !segmentDrafts.isEmpty
    }

    init(context: ModelContext, editing plan: Workout? = nil) {
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
                    existing: plannedExercise
                )
            }
        segmentDrafts = plan.segments
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { segment in
                PlannedSegmentDraft(
                    id: UUID(),
                    label: segment.label,
                    targetDistanceMeters: segment.targetDistanceMeters,
                    targetDurationSeconds: segment.targetDurationSeconds,
                    existing: segment
                )
            }
    }

    func updateName(_ newValue: String) {
        name = newValue
    }

    /// Kraft und Cardio nutzen seit ADR 0009 zwei unabhängige Listen
    /// (`drafts`/`segmentDrafts`) statt geteilter nilable Felder - beim
    /// Sportart-Wechsel muss hier also nichts mehr geleert werden, `save()`
    /// entscheidet beim Speichern, welche Seite persistiert (und welche
    /// geleert) wird.
    func updateActivityType(_ newValue: ActivityType) {
        activityType = newValue
    }

    /// Verhindert, dass dieselbe Übung zweimal in denselben Plan aufgenommen
    /// wird - sonst zeigt der Session-Screen sie als zwei getrennte Karten
    /// mit jeweils bei 1 neu startender Satz-Nummerierung, was verwirrend ist.
    @discardableResult
    func addExercise(_ exercise: Exercise) -> Bool {
        guard !drafts.contains(where: { $0.exercise.name == exercise.name }) else {
            validationMessage = "\(exercise.name) ist bereits Teil dieses Workouts."
            return false
        }
        drafts.append(PlannedExerciseDraft(id: UUID(), exercise: exercise, existing: nil))
        return true
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

    func addSegment() {
        segmentDrafts.append(
            PlannedSegmentDraft(id: UUID(), label: "Segment \(segmentDrafts.count + 1)", existing: nil)
        )
    }

    func updateSegmentLabel(id: UUID, _ newValue: String) {
        guard let index = segmentDrafts.firstIndex(where: { $0.id == id }) else { return }
        segmentDrafts[index].label = newValue
    }

    func updateSegmentTargets(id: UUID, distanceMeters: Double?, durationSeconds: Double?) {
        guard let index = segmentDrafts.firstIndex(where: { $0.id == id }) else { return }
        segmentDrafts[index].targetDistanceMeters = distanceMeters
        segmentDrafts[index].targetDurationSeconds = durationSeconds
    }

    func removeSegmentDraft(id: UUID) {
        segmentDrafts.removeAll { $0.id == id }
    }

    func moveSegmentDrafts(from source: IndexSet, to destination: Int) {
        segmentDrafts.move(fromOffsets: source, toOffset: destination)
    }

    @discardableResult
    func save() -> Bool {
        guard canSave else {
            validationMessage = activityType.usesSetLogs
                ? "Name und mindestens eine Übung sind erforderlich."
                : "Name und mindestens ein Segment sind erforderlich."
            return false
        }

        let plan = existingPlan ?? Workout(name: name, activityType: activityType)
        plan.name = name
        plan.activityType = activityType
        if existingPlan == nil {
            context.insert(plan)
        }

        // Kraft und Cardio nutzen getrennte Listen (ADR 0009) - bei jedem
        // Speichern wird die gerade inaktive Seite komplett geleert, sonst
        // blieben beim Umschalten der Sportart eines bestehenden Plans tote
        // Zeilen der alten Seite in der DB hängen (z.B. ein "Radfahren"-Plan
        // mit toten PlannedExercise-Einträgen).
        if activityType.usesSetLogs {
            for segment in plan.segments {
                context.delete(segment)
            }
        } else {
            for plannedExercise in plan.plannedExercises {
                context.delete(plannedExercise)
            }
        }

        if activityType.usesSetLogs {
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
                } else {
                    let plannedExercise = PlannedExercise(
                        orderIndex: index,
                        exercise: draft.exercise,
                        targetSets: draft.targetSets,
                        targetReps: draft.targetReps,
                        targetWeightKg: draft.targetWeightKg
                    )
                    plannedExercise.plan = plan
                    context.insert(plannedExercise)
                }
            }
        } else {
            let keepIDs = Set(segmentDrafts.compactMap { $0.existing?.persistentModelID })
            for segment in plan.segments where !keepIDs.contains(segment.persistentModelID) {
                context.delete(segment)
            }

            for (index, draft) in segmentDrafts.enumerated() {
                if let existing = draft.existing {
                    existing.orderIndex = index
                    existing.label = draft.label
                    existing.targetDistanceMeters = draft.targetDistanceMeters
                    existing.targetDurationSeconds = draft.targetDurationSeconds
                } else {
                    let segment = PlannedSegment(
                        orderIndex: index,
                        label: draft.label,
                        targetDistanceMeters: draft.targetDistanceMeters,
                        targetDurationSeconds: draft.targetDurationSeconds
                    )
                    segment.plan = plan
                    context.insert(segment)
                }
            }
        }

        do {
            try context.save()
            return true
        } catch {
            validationMessage = "Speichern fehlgeschlagen: \(error.localizedDescription)"
            return false
        }
    }
}
