import SwiftData

/// Ein Abschnitt innerhalb eines Cardio-`Workout`s (z.B. "Warmup"/"Sprint"/
/// "Cooldown"). Cardio-Äquivalent zu `PlannedExercise`, aber bewusst ohne
/// Bezug zum `Exercise`-Katalog - Cardio-Sportarten sind keine Liste
/// benannter Übungen, sondern eine Abfolge frei benennbarer Abschnitte
/// (siehe ADR 0009).
@Model
final class PlannedSegment {
    var orderIndex: Int
    var label: String

    // Welche dieser beiden Zielfelder angezeigt werden, hängt von
    // `ActivityType.cardioFieldOptions` ab (z.B. Tennis zeigt keine Distanz).
    var targetDistanceMeters: Double?
    var targetDurationSeconds: Double?

    var plan: Workout?

    init(
        orderIndex: Int,
        label: String,
        targetDistanceMeters: Double? = nil,
        targetDurationSeconds: Double? = nil
    ) {
        self.orderIndex = orderIndex
        self.label = label
        self.targetDistanceMeters = targetDistanceMeters
        self.targetDurationSeconds = targetDurationSeconds
    }
}
