import ActivityKit
import Foundation

/// In App- und Widget-Extension-Target kompiliert (project.yml). Ausschließlich
/// Timestamps + kleine Anzeigewerte, kein hochzählender Counter (ADR 0003) -
/// derselbe Grund gilt auch für den Widget-Prozess, der ebenso suspendiert
/// werden kann wie die App selbst.
struct WorkoutSessionActivityAttributes: ActivityAttributes {
    /// Statischer Schlüssel, um beim Wiederaufnehmen einer offenen Session
    /// (App-Neustart) an eine bereits laufende Activity anzudocken statt
    /// versehentlich eine zweite für dieselbe Session zu starten.
    let sessionID: UUID

    struct ContentState: Codable, Hashable {
        let workoutName: String
        let currentExerciseName: String?
        /// 1-basierte Position innerhalb der aktiven Übung (für das
        /// `"3x12 · 40kg"`-Format: Satz 3, 12 Wdh.).
        let currentSetNumber: Int?
        let currentSetReps: Int?
        let currentSetWeight: Double?
        /// Abschluss-Status jedes Satzes der aktiven Übung, in Satz-Reihenfolge
        /// (`setIndex`-sortiert) - Grundlage für die Satz-Fortschrittsleiste
        /// inkl. Verschmelzung benachbarter erledigter Sätze. Ersetzt die
        /// frühere Übungs-Fortschritts-Punktereihe (`totalExerciseCount`/
        /// `completedExerciseCount`) durch Satz- statt Übungs-Granularität.
        let currentExerciseSetCompletionFlags: [Bool]
        let restTimerStartDate: Date?
        let restTimerDuration: TimeInterval?
    }
}

extension WorkoutSessionActivityAttributes.ContentState {
    /// Kompaktes Format ohne Extra-Label (User-Vorgabe), z.B. `"3x12 · 40kg"`.
    /// `nil` sobald eine der drei Komponenten fehlt, statt ein unvollständiges
    /// Format anzuzeigen.
    var compactSetDescription: String? {
        guard
            let setNumber = currentSetNumber,
            let reps = currentSetReps,
            let weight = currentSetWeight
        else { return nil }
        // Gleiches Format-Pattern wie RecentPersonalRecordsList.swift/
        // PreviousSessionComparisonCard.swift, statt einer zweiten,
        // unabhängigen Gewichts-Formatierung.
        return "\(setNumber)x\(reps) · \(weight.formatted(.number.precision(.fractionLength(0...1))))kg"
    }
}
