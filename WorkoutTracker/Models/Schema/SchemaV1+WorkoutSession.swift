import SwiftData
import Foundation

@Model
final class WorkoutSession {
    /// Explizite eigene ID statt `persistentModelID` - Voraussetzung für
    /// den künftigen HealthKit-Dedup-Abgleich (Phase E).
    @Attribute(.unique) var id: UUID
    var activityType: ActivityType
    var startDate: Date
    var endDate: Date?
    var notes: String?

    // Cardio-Metrik-Block - nil bei activityType == .kraft.
    // Dauer wird bewusst NICHT separat gespeichert (ADR 0003:
    // startDate/endDate sind die Quelle der Wahrheit, keine
    // akkumulierten Zahlen).
    var distanceMeters: Double?
    var averageHeartRate: Int?

    // HealthKit-Dedup-Vorbereitung (Schreibrichtung App->Health via
    // healthKitUUID, Leserichtung Health->App via source, Phase E).
    var healthKitUUID: UUID?
    var source: SessionSource

    // .cascade: ein SetLog hat außerhalb seiner Session keine Bedeutung.
    @Relationship(deleteRule: .cascade, inverse: \SetLog.session)
    var setLogs: [SetLog] = []

    // .nullify: Gegenstück zu WorkoutPlan.sessions.
    var plan: WorkoutPlan?

    // .cascade: ein ChallengeProgressEntry existiert nur, weil diese
    // Session ihn ausgelöst hat (ADR 0002). Wird die auslösende Session
    // gelöscht, muss der abgeleitete Log-Eintrag mit verschwinden,
    // sonst zählt ein "Phantom-Fortschritt" weiter mit.
    @Relationship(deleteRule: .cascade, inverse: \ChallengeProgressEntry.triggeringSession)
    var challengeProgressEntries: [ChallengeProgressEntry] = []

    init(
        id: UUID = UUID(),
        activityType: ActivityType,
        startDate: Date = .now,
        endDate: Date? = nil,
        plan: WorkoutPlan? = nil,
        source: SessionSource = .manual,
        healthKitUUID: UUID? = nil
    ) {
        self.id = id
        self.activityType = activityType
        self.startDate = startDate
        self.endDate = endDate
        self.plan = plan
        self.source = source
        self.healthKitUUID = healthKitUUID
    }
}
