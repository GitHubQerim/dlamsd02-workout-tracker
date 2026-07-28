import SwiftData

/// Ein geloggter Abschnitt einer Cardio-`WorkoutSession`. Cardio-Äquivalent
/// zu `SetLog`: `distanceMeters`/`durationSeconds` sind die tatsächlich
/// geloggten Werte (nicht separat vom Ziel gehalten), analog zu
/// `SetLog.reps`/`weightKg`.
///
/// Bewusst KEIN `createdAt` wie bei `SetLog`: dort braucht es einen globalen
/// Tiebreaker, weil `setIndex` pro Übung bei 0 neu beginnt. Segmente haben
/// dagegen von Anfang an eine einzige, flache, globale Reihenfolge über
/// `orderIndex`.
@Model
final class SegmentLog {
    var orderIndex: Int

    /// Snapshot von `PlannedSegment.label` bei Session-Start, oder frei
    /// vergeben bei Ad-hoc-Segmenten im freien Training.
    var label: String

    var distanceMeters: Double?
    var durationSeconds: Double?
    var isCompleted: Bool

    var session: WorkoutSession?

    init(
        orderIndex: Int,
        label: String,
        distanceMeters: Double? = nil,
        durationSeconds: Double? = nil,
        isCompleted: Bool = false
    ) {
        self.orderIndex = orderIndex
        self.label = label
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
        self.isCompleted = isCompleted
    }
}
