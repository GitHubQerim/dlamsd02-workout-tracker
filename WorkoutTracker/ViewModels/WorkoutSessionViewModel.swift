import ActivityKit
import Foundation
import OSLog
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
/// die View bindet direkt gegen `session.startDate`/`session.plan`/etc.
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
    private let healthKitService: HealthKitServicing

    private(set) var restTimerStartDate: Date?
    var restTimerDuration: TimeInterval = 90
    private var liveActivity: Activity<WorkoutSessionActivityAttributes>?

    /// Ergebnis der Rang-/Elo-Reconciliation aus `finishSession()` (ADR
    /// 0014) - `nil` bis die Session beendet wurde, danach von
    /// `WorkoutCompletionView` für die Streak-/Elo-/Rang-Aufstieg-Anzeige
    /// gelesen.
    private(set) var lastRankReconciliation: RankReconciliationResult?

    var isRestTimerRunning: Bool { restTimerStartDate != nil }

    init(context: ModelContext, session: WorkoutSession, healthKitService: HealthKitServicing = HealthKitService()) {
        self.context = context
        self.session = session
        self.id = session.id
        self.healthKitService = healthKitService
        attachOrStartLiveActivity()
    }

    /// Legt eine neue Session an (+ vorbefüllte Sätze bei einem Kraft-Plan)
    /// und persistiert sie sofort, damit sie auch bei App-Beendigung während
    /// der laufenden Session nicht verloren geht (siehe Re-Entrancy-Schutz
    /// in WorkoutsView/DashboardView).
    static func start(
        context: ModelContext,
        plan: Workout?,
        activityType: ActivityType,
        healthKitService: HealthKitServicing = HealthKitService()
    ) -> WorkoutSessionViewModel {
        let session = makeSession(context: context, plan: plan, activityType: activityType)
        try? context.save()
        return WorkoutSessionViewModel(context: context, session: session, healthKitService: healthKitService)
    }

    /// Startet eine Session aus einem `WorkoutProgram`-Tag heraus und
    /// stempelt den Programm-/Tag-Snapshot auf die Session (siehe Kommentar
    /// an `WorkoutSession.programEntryID`). `nil`, wenn der Tag keinen
    /// lebenden Workout-Link mehr hat (Workout wurde gelöscht) - die UI
    /// blendet den Start-Button in diesem Fall ohnehin aus.
    static func start(
        context: ModelContext,
        programEntry: WorkoutProgramEntry,
        programName: String,
        healthKitService: HealthKitServicing = HealthKitService()
    ) -> WorkoutSessionViewModel? {
        guard let workout = programEntry.workout else { return nil }
        let session = makeSession(context: context, plan: workout, activityType: workout.activityType)
        session.programEntryID = programEntry.id
        session.programName = programName
        session.programDayLabel = programEntry.dayLabel
        try? context.save()
        return WorkoutSessionViewModel(context: context, session: session, healthKitService: healthKitService)
    }

    /// Baut Session + vorbefüllte Sätze/Segmente, speichert aber NICHT selbst
    /// - beide `start`-Overloads speichern jeweils genau einmal, nachdem der
    /// Programm-Fall zusätzlich noch die Snapshot-Felder gesetzt hat.
    private static func makeSession(context: ModelContext, plan: Workout?, activityType: ActivityType) -> WorkoutSession {
        let session = WorkoutSession(activityType: activityType, plan: plan)
        context.insert(session)

        guard let plan else { return session }

        if activityType.usesSetLogs {
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
        } else {
            // Ziel wird Start-/Editierwert (analog zur Reps/Gewicht-
            // Vorbefüllung bei Kraft) - der Nutzer passt während der Session
            // an, was tatsächlich gelaufen ist.
            for segment in plan.segments.sorted(by: { $0.orderIndex < $1.orderIndex }) {
                let segmentLog = SegmentLog(
                    orderIndex: segment.orderIndex,
                    label: segment.label,
                    distanceMeters: segment.targetDistanceMeters,
                    durationSeconds: segment.targetDurationSeconds
                )
                segmentLog.session = session
                context.insert(segmentLog)
            }
        }

        return session
    }

    /// Programmtag-Snapshot zuerst (überlebt Löschung des Plans/Programms),
    /// dann direkter Plan-Name, dann activityType als letzter Fallback für
    /// freies Training ohne Plan. Einzige Stelle dieser Fallback-Kette -
    /// wird auch von liveActivityContentState genutzt, damit Header und Live
    /// Activity nie auseinanderlaufen.
    var displayTitle: String {
        session.programName ?? session.plan?.name ?? session.activityType.displayName
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

    /// Ob wirklich alle Sätze (Kraft) bzw. Segmente (Cardio) der Session
    /// abgehakt sind - Grundlage für den "Workout abschließen"-Zustand der
    /// permanenten Bottom-Pille (`WorkoutSessionView.finishBar`).
    var isWorkoutComplete: Bool {
        if session.activityType.usesSetLogs {
            !session.setLogs.isEmpty && session.setLogs.allSatisfy(\.isCompleted)
        } else {
            !session.segmentLogs.isEmpty && session.segmentLogs.allSatisfy(\.isCompleted)
        }
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
    /// Fetch+Scan ausgelagert in `WorkoutSession.mostRecentCompletedSession`
    /// (`Support/PreviousSessionLookup.swift`), gemeinsam genutzt mit dem
    /// Überlastungs-Bonus des Rang-Systems (ADR 0014).
    func previousAttempt(for exerciseName: String) -> PreviousAttempt? {
        guard let candidate = WorkoutSession.mostRecentCompletedSession(
            containingExerciseName: exerciseName,
            excluding: session.id,
            in: context
        ) else { return nil }

        let matchingSets = candidate.setLogs
            .filter { $0.exerciseName == exerciseName }
            .sorted { $0.setIndex < $1.setIndex }
        return PreviousAttempt(
            date: candidate.startDate,
            planName: candidate.plan?.name,
            sets: matchingSets.map {
                PreviousSetSnapshot(setIndex: $0.setIndex, reps: $0.reps, weightKg: $0.weightKg)
            }
        )
    }

    func toggleSetCompletion(_ setLog: SetLog) {
        setLog.isCompleted.toggle()
        persist()
        if setLog.isCompleted {
            // startRestTimer() aktualisiert die Live Activity bereits selbst -
            // sonst genau einmal hier, nie beide (kein doppelter Activity.update).
            startRestTimer()
        } else {
            updateLiveActivity()
        }
    }

    func updateSet(_ setLog: SetLog, reps: Int, weightKg: Double) {
        setLog.reps = reps
        setLog.weightKg = weightKg
        persist()
        updateLiveActivity()
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
        updateLiveActivity()
    }

    func skipRestTimer() {
        restTimerStartDate = nil
        updateLiveActivity()
    }

    func adjustRestDuration(by delta: TimeInterval) {
        restTimerDuration = max(15, restTimerDuration + delta)
        updateLiveActivity()
    }

    /// Startet eine neue Live Activity oder dockt an eine bereits laufende
    /// derselben Session an (App-Neustart bei offener Session) - verhindert
    /// eine zweite, doppelte Activity für dieselbe Session. Nur für Kraft-
    /// Sessions (Übungsfortschritt/Sätze sind die einzigen im Content-State
    /// abgebildeten Werte, siehe `WorkoutSessionActivityAttributes`).
    private func attachOrStartLiveActivity() {
        guard session.activityType.usesSetLogs else { return }
        if let existing = Activity<WorkoutSessionActivityAttributes>.activities.first(where: { $0.attributes.sessionID == session.id }) {
            liveActivity = existing
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        do {
            liveActivity = try Activity.request(
                attributes: WorkoutSessionActivityAttributes(sessionID: session.id),
                content: .init(state: liveActivityContentState, staleDate: nil)
            )
        } catch {
            // Kein Blocker - Live Activity ist ein Zusatzfeature, die Session
            // bleibt unabhängig davon voll nutzbar. Logger statt komplettem
            // Schweigen, sonst nirgends nachvollziehbar (z.B. bei Erreichen
            // des System-Limits gleichzeitiger Activities).
            Logger(subsystem: "com.qerim.dlamsd02.workouttracker", category: "LiveActivity")
                .error("Live Activity konnte nicht gestartet werden: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func updateLiveActivity() {
        guard let liveActivity else { return }
        let state = liveActivityContentState
        Task { await liveActivity.update(.init(state: state, staleDate: nil)) }
    }

    private func endLiveActivity() {
        guard let liveActivity else { return }
        let state = liveActivityContentState
        Task { await liveActivity.end(.init(state: state, staleDate: nil), dismissalPolicy: .immediate) }
        self.liveActivity = nil
    }

    /// Nicht `private`, damit die Projektion aus ViewModel-State direkt
    /// unit-testbar ist (Live-Activity-`Activity`-Handling selbst ist es
    /// nicht, siehe Testkommentar in `WorkoutSessionViewModelTests`).
    var liveActivityContentState: WorkoutSessionActivityAttributes.ContentState {
        let sections = exerciseSections
        let activeExerciseName = firstIncompleteExerciseName
        let activeSection = sections.first { $0.name == activeExerciseName }
        let activeSet = activeSection?.sets.first { !$0.isCompleted }

        return WorkoutSessionActivityAttributes.ContentState(
            workoutName: displayTitle,
            currentExerciseName: activeExerciseName,
            currentSetNumber: activeSet.map { $0.setIndex + 1 },
            currentSetReps: activeSet?.reps,
            currentSetWeight: activeSet?.weightKg,
            currentExerciseSetCompletionFlags: activeSection?.sets.map(\.isCompleted) ?? [],
            restTimerStartDate: restTimerStartDate,
            restTimerDuration: isRestTimerRunning ? restTimerDuration : nil
        )
    }

    /// Sortierte Segmente der Session - Cardio-Äquivalent zu `exerciseSections`.
    /// Keine eigene Struct nötig: `SegmentLog` trägt Label/Werte/Status
    /// bereits direkt (anders als Kraft, wo `ExerciseSection` Sätze unter
    /// einem Übungsnamen gruppiert - Segmente haben keine solche Verschachtelung).
    var segmentSections: [SegmentLog] {
        session.segmentLogs.sorted { $0.orderIndex < $1.orderIndex }
    }

    func toggleSegmentCompletion(_ segmentLog: SegmentLog) {
        segmentLog.isCompleted.toggle()
        persist()
    }

    func updateSegment(_ segmentLog: SegmentLog, distanceMeters: Double?, durationSeconds: Double?) {
        segmentLog.distanceMeters = distanceMeters
        segmentLog.durationSeconds = durationSeconds
        persist()
    }

    /// Ad-hoc-Segment fürs freie Training - analog zu `addSet(for:)`.
    func addSegment(label: String) {
        let segmentLog = SegmentLog(orderIndex: session.segmentLogs.count, label: label)
        segmentLog.session = session
        context.insert(segmentLog)
        persist()
    }

    func updateAverageHeartRate(_ averageHeartRate: Int?) {
        session.averageHeartRate = averageHeartRate
        persist()
    }


    /// Schreibt nur Kraft-Sessions nach Apple Health (Cardio kommt
    /// ausschließlich per Import umgekehrt herein, siehe ADR 0012) - der
    /// lokale `persist()` passiert zuerst und unabhängig vom HK-Ergebnis,
    /// ein fehlschlagender HK-Save darf die lokal beendete Session nie
    /// blockieren oder ungültig machen.
    func finishSession() async {
        assert(
            !(session.activityType.usesSetLogs && !session.segmentLogs.isEmpty),
            "Kraft-Sessions dürfen keine SegmentLogs tragen"
        )
        assert(
            !(session.activityType.usesSetLogs && session.averageHeartRate != nil),
            "Kraft-Sessions dürfen keinen Puls tragen"
        )
        assert(
            session.activityType.usesSetLogs || session.setLogs.isEmpty,
            "Cardio-Sessions dürfen keine SetLogs tragen"
        )
        session.endDate = .now
        session.materializeChallengeProgress(in: context)
        session.detectAndPersistPersonalRecords(in: context)
        lastRankReconciliation = session.updateRankProgress(in: context)
        restTimerStartDate = nil
        persist()
        WidgetSnapshotRefresher.refresh(context: context)
        endLiveActivity()

        guard session.activityType.usesSetLogs, let endDate = session.endDate else { return }
        do {
            let healthKitUUID = try await healthKitService.saveStrengthSession(
                HealthKitOutgoingSession(
                    activityType: session.activityType,
                    start: session.startDate,
                    end: endDate
                )
            )
            session.healthKitUUID = healthKitUUID
            persist()
        } catch {
            // Kein Re-Throw: die Session bleibt lokal gültig und gespeichert,
            // ein fehlgeschlagener HealthKit-Save ist kein Blocker.
        }
    }

    /// Best-effort Löschung eines bereits geschriebenen HK-Samples - Fehler
    /// werden bewusst ignoriert, die lokale Löschung darf nie daran hängen.
    func discardSession() async {
        if let healthKitUUID = session.healthKitUUID {
            try? await healthKitService.deleteSession(healthKitUUID: healthKitUUID)
        }
        endLiveActivity()
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
