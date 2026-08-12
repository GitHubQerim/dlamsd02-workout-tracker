import Foundation

/// Eigene, HealthKit-freie DTOs statt roher `HKWorkout`/`HKSample`-Typen -
/// hält HealthKit-Details vollständig hinter dieser Grenze (ADR 0011).
/// Kein `averageHeartRate`-Feld: `finishSession()` schreibt nur Kraft-
/// Sessions nach Health, und Kraft-Sessions dürfen laut ADR 0009 nie einen
/// Puls tragen (siehe Assert in `WorkoutSessionViewModel.finishSession()`)
/// - ein Feld dafür wäre hier strukturell nie befüllbar.
struct HealthKitOutgoingSession: Sendable {
    let activityType: ActivityType
    let start: Date
    let end: Date
    /// `nil` überspringt das Schreiben von `activeEnergyBurned` komplett -
    /// z.B. wenn kein Körpergewicht aus Health gelesen werden konnte
    /// (`EnergyEstimator` liefert dann bewusst keine geratene Zahl).
    let activeEnergyKcal: Double?
}

struct HealthKitWorkoutSample: Identifiable, Sendable {
    let id: UUID
    let hkActivityType: HealthKitWorkoutActivityKind
    let start: Date
    let end: Date
    let totalDistanceMeters: Double?
    let averageHeartRate: Int?
}

/// Eigene, kleine Kopie der für uns relevanten `HKWorkoutActivityType`-Fälle -
/// bewusst kein Import von HealthKit-Typen über die Protokoll-Grenze hinweg.
enum HealthKitWorkoutActivityKind: Sendable, Equatable {
    case cycling
    case running
    case tennis
    case other
}

/// Bewusst als einzige, dokumentierte Ausnahme vom sonst zustandslosen
/// Extension-Stil des Projekts eingeführt (ADR 0011) - `HKHealthStore` ist
/// selbst ein Objekt mit Lebenszyklus (Autorisierungsstatus, Queries).
///
/// Arbeitet ausschließlich mit eigenen DTOs, nie mit `ModelContext` - die
/// Rückschreibung nach SwiftData passiert immer im Aufrufer, synchron nach
/// einem `await`, mit dem ohnehin im Scope gehaltenen Context (ADR 0001).
protocol HealthKitServicing: Sendable {
    /// Echter, vom Betriebssystem gehaltener Autorisierungsstatus - nie
    /// selbst persistieren, sonst driftet der App-Zustand vom tatsächlichen
    /// Health-Berechtigungsstatus auseinander (z.B. wenn der Nutzer die
    /// Berechtigung in den iOS-Einstellungen widerruft).
    func isAuthorized() -> Bool
    func requestAuthorization() async throws
    @discardableResult
    func saveStrengthSession(_ session: HealthKitOutgoingSession) async throws -> UUID
    func deleteSession(healthKitUUID: UUID) async throws
    func fetchImportableCardioWorkouts(excluding existingUUIDs: Set<UUID>) async throws -> [HealthKitWorkoutSample]
    /// Neuester `bodyMass`-Wert aus Health, in kg - `nil` falls keine
    /// Daten vorhanden oder der Lesezugriff nicht autorisiert ist.
    func fetchLatestBodyWeightKg() async throws -> Double?
    /// Kalendertage seit `since`, an denen der "Bewegen"-Aktivitätsring
    /// geschlossen wurde (`activeEnergyBurned >= activeEnergyBurnedGoal`) -
    /// reine `Date`s, kein `HKActivitySummary` überschreitet die Protokoll-
    /// Grenze (ADR 0011). Tage ohne Activity-Summary fehlen einfach im
    /// Ergebnis (= "nicht geschlossen"). Fehlerfall (keine Berechtigung,
    /// Query-Fehler) ist Sache des Aufrufers - degradiert NICHT hier auf ein
    /// leeres Set, jeder Aufrufer wendet `try?` selbst an, analog
    /// `fetchLatestBodyWeightKg` (siehe ADR 0015).
    func fetchClosedMoveRingDates(since: Date, calendar: Calendar) async throws -> Set<Date>
}
