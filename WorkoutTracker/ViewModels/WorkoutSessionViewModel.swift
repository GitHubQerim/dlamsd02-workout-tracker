import Foundation
import SwiftData

/// Eine Übung innerhalb der Session mit ihren Sätzen und - sofern aus einem
/// Plan gestartet - dem zugehörigen Zielwert. Eigene Struct statt Tupel, um
/// Drift zwischen ViewModel und den (mehreren) Views zu vermeiden, die
/// darauf zugreifen.
struct ExerciseSection: Identifiable {
    let name: String
    let sets: [SetLog]
    let target: PlannedExercise?
    var id: String { name }
}

/// Wertetyp-Snapshot eines Satzes aus einer vergangenen Session - bewusst
/// kein `@Model`-Handle, damit die Vergleichs-Anzeige fremde, abgeschlossene
/// Sätze nie versehentlich editieren kann.
struct PreviousSetSnapshot: Identifiable {
    let id = UUID()
    let setIndex: Int
    let reps: Int
    let weightKg: Double
}

struct PreviousAttempt {
    let date: Date
    let planName: String?
    let sets: [PreviousSetSnapshot]
}

/// Steuert eine laufende `WorkoutSession`. Dupliziert keine persistierten
/// Felder als eigenen State - `session` ist bereits über `@Model` observable,
/// die View bindet direkt gegen `session.startDate`/`session.notes`/etc.
/// Das ViewModel hält nur echten ephemeren State (Pausen-Timer) und die
/// Mutator-Methoden. Kein eigener Task/Timer (siehe ADR 0003) - Gesamt- und
/// Pausen-Timer werden in der View per `TimelineView` gegen `startDate`
/// berechnet, hier gibt es nur den Startzeitpunkt, nie einen Zähler.
@Observable
@MainActor
final class WorkoutSessionViewModel: Identifiable {
    // Eigene, unveränderliche Kopie statt `session.id` als computed property:
    // `Identifiable.id` ist nicht actor-isoliert, ein Lesezugriff auf das
    // @MainActor-gebundene `session` wäre dort ein Swift-6-Concurrency-Fehler.
    let id: UUID
    let session: WorkoutSession
    private let context: ModelContext

    private(set) var restTimerStartDate: Date?
    var restTimerDuration: TimeInterval = 90

    var isRestTimerRunning: Bool { restTimerStartDate != nil }

    init(context: ModelContext, session: WorkoutSession) {
        self.context = context
        self.session = session
        self.id = session.id
    }

    /// Legt eine neue Session an (+ vorbefüllte Sätze bei einem Kraft-Plan)
    /// und persistiert sie sofort, damit sie auch bei App-Beendigung während
    /// der laufenden Session nicht verloren geht (siehe Re-Entrancy-Schutz
    /// in WorkoutsView/DashboardView).
    static func start(context: ModelContext, plan: WorkoutPlan?, activityType: ActivityType) -> WorkoutSessionViewModel {
        let session = WorkoutSession(activityType: activityType, plan: plan)
        context.insert(session)

        if activityType.usesSetLogs, let plan {
            for plannedExercise in plan.plannedExercises.sorted(by: { $0.orderIndex < $1.orderIndex }) {
                guard let exercise = plannedExercise.exercise else { continue }
                let setCount = max(1, plannedExercise.targetSets ?? 1)
                for setIndex in 0..<setCount {
                    let setLog = SetLog(
                        setIndex: setIndex,
                        exercise: exercise,
                        reps: plannedExercise.targetReps ?? 0,
                        weightKg: plannedExercise.targetWeightKg ?? 0
                    )
                    setLog.session = session
                    context.insert(setLog)
                }
            }
        }

        try? context.save()
        return WorkoutSessionViewModel(context: context, session: session)
    }

    /// Übungen in Plan-Reihenfolge (bzw. Erst-Auftrittsreihenfolge bei
    /// freiem Training ohne Plan), jeweils mit ihren Sätzen und - sofern aus
    /// einem Plan gestartet - dem zugehörigen Zielwert.
    var exerciseSections: [ExerciseSection] {
        let orderedNames: [String]
        if let plan = session.plan {
            orderedNames = plan.plannedExercises
                .sorted { $0.orderIndex < $1.orderIndex }
                .map(\.exerciseName)
        } else {
            // `setIndex` beginnt pro Übung bei 0 und eignet sich daher NICHT
            // zur Erst-Auftrittsreihenfolge über mehrere Übungen hinweg
            // (zwei Übungen können denselben setIndex haben) - `createdAt`
            // ist global ordnend.
            orderedNames = session.setLogs
                .sorted { $0.createdAt < $1.createdAt }
                .reduce(into: [String]()) { names, setLog in
                    if !names.contains(setLog.exerciseName) {
                        names.append(setLog.exerciseName)
                    }
                }
        }
        return orderedNames.map { name in
            ExerciseSection(
                name: name,
                sets: session.setLogs.filter { $0.exerciseName == name }.sorted { $0.setIndex < $1.setIndex },
                target: session.plan?.plannedExercises.first { $0.exerciseName == name }
            )
        }
    }

    /// Sinnvoller Akkordeon-Default: erste Übung mit mindestens einem
    /// offenen Satz, sonst (alles erledigt) die letzte Übung, damit nie
    /// "nichts" aufgeklappt ist.
    var firstIncompleteExerciseName: String? {
        exerciseSections.first { $0.sets.contains { !$0.isCompleted } }?.name
            ?? exerciseSections.last?.name
    }

    func isExerciseComplete(_ name: String) -> Bool {
        guard let section = exerciseSections.first(where: { $0.name == name }) else { return false }
        return !section.sets.isEmpty && section.sets.allSatisfy(\.isCompleted)
    }

    /// Nächster offener Satz einer Übung (erster mit `isCompleted == false`,
    /// Reihenfolge über `setIndex`) - Grundlage für den "als nächstes dran"-
    /// Indikator in der aktiven Übungskarte.
    func nextIncompleteSetID(in exerciseName: String) -> PersistentIdentifier? {
        exerciseSections
            .first(where: { $0.name == exerciseName })?
            .sets.first(where: { !$0.isCompleted })?
            .persistentModelID
    }

    /// Letzte ABGESCHLOSSENE, andere Session, die mindestens einen Satz zu
    /// `exerciseName` enthält - Grundlage für den "Letztes Mal"-Vergleich.
    /// Bewusst kein `#Predicate` über die `setLogs`-Relationship (siehe ADR
    /// 0001: SwiftData kann Relationship-Traversierung dort nicht zuverlässig
    /// abbilden) - stattdessen ein einfacher, nach Datum sortierter Fetch
    /// aller fremden abgeschlossenen Sessions, danach Swift-seitiger Scan
    /// mit frühem Abbruch beim ersten Treffer.
    func previousAttempt(for exerciseName: String) -> PreviousAttempt? {
        let currentID = session.id
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.endDate != nil && $0.id != currentID },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        guard let candidates = try? context.fetch(descriptor) else { return nil }

        for candidate in candidates {
            let matchingSets = candidate.setLogs
                .filter { $0.exerciseName == exerciseName }
                .sorted { $0.setIndex < $1.setIndex }
            guard !matchingSets.isEmpty else { continue }
            return PreviousAttempt(
                date: candidate.startDate,
                planName: candidate.plan?.name,
                sets: matchingSets.map {
                    PreviousSetSnapshot(setIndex: $0.setIndex, reps: $0.reps, weightKg: $0.weightKg)
                }
            )
        }
        return nil
    }

    func toggleSetCompletion(_ setLog: SetLog) {
        setLog.isCompleted.toggle()
        persist()
        if setLog.isCompleted {
            startRestTimer()
        }
    }

    func updateSet(_ setLog: SetLog, reps: Int, weightKg: Double) {
        setLog.reps = reps
        setLog.weightKg = weightKg
        persist()
    }

    /// Fügt einen weiteren Satz hinzu - sowohl für geplante als auch für
    /// im freien Training ad-hoc gewählte Übungen nutzbar.
    func addSet(for exercise: Exercise, suggestedReps: Int? = nil, suggestedWeightKg: Double? = nil) {
        let existingCount = session.setLogs.filter { $0.exerciseName == exercise.name }.count
        let setLog = SetLog(
            setIndex: existingCount,
            exercise: exercise,
            reps: suggestedReps ?? 0,
            weightKg: suggestedWeightKg ?? 0
        )
        setLog.session = session
        context.insert(setLog)
        persist()
    }

    func startRestTimer() {
        restTimerStartDate = .now
    }

    func skipRestTimer() {
        restTimerStartDate = nil
    }

    func adjustRestDuration(by delta: TimeInterval) {
        restTimerDuration = max(15, restTimerDuration + delta)
    }

    func updateCardioMetrics(distanceMeters: Double?, averageHeartRate: Int?) {
        session.distanceMeters = distanceMeters
        session.averageHeartRate = averageHeartRate
        persist()
    }

    func updateNotes(_ text: String) {
        session.notes = text.isEmpty ? nil : text
        persist()
    }

    func finishSession() {
        assert(
            !(session.activityType.usesSetLogs && (session.distanceMeters != nil || session.averageHeartRate != nil)),
            "Kraft-Sessions dürfen keine Cardio-Metriken tragen"
        )
        session.endDate = .now
        restTimerStartDate = nil
        persist()
        // Anknüpfpunkt Phase D: ChallengeProgressEntry-Erzeugung (ADR 0002) kommt hier rein.
    }

    func discardSession() {
        context.delete(session)
        persist()
    }

    private func persist() {
        do {
            try context.save()
        } catch {
            assertionFailure("Session-Speichern fehlgeschlagen: \(error)")
        }
    }
}
