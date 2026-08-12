import Foundation

/// Grobe kcal-Schätzung für Kraftsessions über die MET-Formel
/// (kcal = MET × Körpergewicht(kg) × Dauer(h)), bewusst reines Swift ohne
/// HealthKit-Import (unit-testbar ohne Mock/Autorisierung, gleicher Stil
/// wie `HealthKitActivityMapping`).
///
/// Der MET-Wert ist kein fixer Konstantwert, sondern wird aus einer
/// lastnormierten Arbeitsrate abgeleitet: bewegtes Trainingsvolumen
/// (Σ Wiederholungen × Gewicht) pro Minute, normiert auf das
/// Körpergewicht. Die drei Stufen (3.5/5.0/6.0) sind an die MET-Anker des
/// Compendium of Physical Activities für Krafttraining angelehnt (leicht/
/// moderat/intensiv) - das ist eine grobe Näherung wie in üblichen
/// Fitness-Apps, kein medizinisch exakter Wert. Schwellwerte und MET-Werte
/// sind bewusst tunbar, nicht autoritativ.
enum EnergyEstimator {
    private static let lightMET = 3.5
    private static let moderateMET = 5.0
    private static let vigorousMET = 6.0

    private static let moderateThreshold = 0.8
    private static let vigorousThreshold = 1.5

    /// Obergrenze für die in die Formel eingehende Dauer - `endDate` ist der
    /// Zeitpunkt, an dem der Nutzer "beenden" tippt, nicht das Ende der
    /// tatsächlichen Belastung. Bleibt die App über Stunden im Hintergrund
    /// offen, würde die reine Wanduhrzeit sonst eine absurd hohe kcal-Zahl
    /// ergeben - 3h deckt jede plausible Kraftsession ab.
    private static let maxPlausibleDuration: TimeInterval = 3 * 3600

    /// `nil`, wenn eine der Eingaben keine sinnvolle Schätzung zulässt
    /// (keine abgeschlossenen Sätze, kein Körpergewicht, degenerierte
    /// Dauer) - eine fehlende Zahl ist besser als eine geratene.
    static func estimatedActiveEnergyKcal(
        totalVolumeKg: Double,
        bodyWeightKg: Double,
        duration: TimeInterval
    ) -> Double? {
        guard totalVolumeKg > 0, bodyWeightKg > 0, duration > 0 else { return nil }

        let cappedDuration = min(duration, maxPlausibleDuration)
        let durationMinutes = max(cappedDuration / 60, 1)
        let relativeIntensity = (totalVolumeKg / durationMinutes) / bodyWeightKg

        let met: Double = if relativeIntensity > vigorousThreshold {
            vigorousMET
        } else if relativeIntensity > moderateThreshold {
            moderateMET
        } else {
            lightMET
        }

        return met * bodyWeightKg * (cappedDuration / 3600)
    }
}
