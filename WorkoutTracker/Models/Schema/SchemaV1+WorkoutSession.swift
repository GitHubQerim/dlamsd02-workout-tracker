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

    // Puls bleibt ein flaches, Session-weites Feld - nicht sinnvoll pro
    // Segment aufteilbar in dieser manuell erfassten App (ADR 0009).
    // Distanz kommt jetzt aus `segmentLogs` (siehe `totalDistanceMeters`
    // in Support/WorkoutSessionFormatting.swift), kein eigenes Feld mehr.
    var averageHeartRate: Int?

    // HealthKit-Dedup-Vorbereitung (Schreibrichtung App->Health via
    // healthKitUUID, Leserichtung Health->App via source, Phase E).
    var healthKitUUID: UUID?
    var source: SessionSource

    // .cascade: ein SetLog hat außerhalb seiner Session keine Bedeutung.
    // Nur bei Kraft-Sessions befüllt (siehe ADR 0009).
    @Relationship(deleteRule: .cascade, inverse: \SetLog.session)
    var setLogs: [SetLog] = []

    // .cascade: ein SegmentLog hat außerhalb seiner Session keine Bedeutung.
    // Nur bei Cardio-Sessions befüllt - Kraft und Cardio nutzen bewusst
    // getrennte Listen statt eines geteilten Metrik-Blocks (ADR 0009).
    @Relationship(deleteRule: .cascade, inverse: \SegmentLog.session)
    var segmentLogs: [SegmentLog] = []

    // .nullify: Gegenstück zu Workout.sessions.
    var plan: Workout?

    // Snapshot des WorkoutProgram-Tages, aus dem diese Session gestartet
    // wurde - bewusst getrennt von `plan` (dem Live-Link zum Workout dieses
    // Tages). `programEntryID` ist der primäre Schlüssel für "letzter/
    // nächster Tag"-Auflösung (siehe WorkoutProgram+NextEntry.swift);
    // `programName`/`programDayLabel` sind nur Anzeige-Snapshots, die auch
    // dann noch lesbar bleiben, wenn das Programm oder der Tag später
    // umbenannt, umsortiert oder gelöscht wurde. Alle drei sind nil, wenn
    // die Session nicht aus einem Programm gestartet wurde (freies Training
    // oder direkter Workout-Start).
    var programEntryID: UUID?
    var programName: String?
    var programDayLabel: String?

    // .cascade: ein ChallengeProgressEntry existiert nur, weil diese
    // Session ihn ausgelöst hat (ADR 0002). Wird die auslösende Session
    // gelöscht, muss der abgeleitete Log-Eintrag mit verschwinden,
    // sonst zählt ein "Phantom-Fortschritt" weiter mit.
    @Relationship(deleteRule: .cascade, inverse: \ChallengeProgressEntry.triggeringSession)
    var challengeProgressEntries: [ChallengeProgressEntry] = []

    // .cascade: ein PersonalRecord ohne seine auslösende Session wäre ein
    // Phantom-Rekord - gleiches Argument wie bei challengeProgressEntries
    // (ADR 0002/0010).
    @Relationship(deleteRule: .cascade, inverse: \PersonalRecord.session)
    var personalRecords: [PersonalRecord] = []

    init(
        id: UUID = UUID(),
        activityType: ActivityType,
        startDate: Date = .now,
        endDate: Date? = nil,
        plan: Workout? = nil,
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
