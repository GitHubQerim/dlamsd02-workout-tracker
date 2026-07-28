import Foundation

extension WorkoutSession {
    /// Gesamtdistanz über alle Segmente - `nil` wenn diese Session keine
    /// Segmente hat (Kraft-Sessions, oder Cardio-Sessions ohne einziges
    /// Segment). Ersetzt seit ADR 0009 das frühere flache
    /// `WorkoutSession.distanceMeters`-Feld.
    var totalDistanceMeters: Double? {
        guard !segmentLogs.isEmpty else { return nil }
        return segmentLogs.reduce(0) { $0 + ($1.distanceMeters ?? 0) }
    }
}
