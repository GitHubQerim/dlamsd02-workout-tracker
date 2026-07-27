import Foundation

extension PlannedExercise {
    /// Kompakte Zielwert-Zusammenfassung, z.B. "3 × 8 · 60 kg". Blendet
    /// fehlende Werte aus statt "0" zu zeigen - während einer laufenden
    /// Session stünde eine "0" sonst missverständlich neben echten
    /// Eingabewerten (anders als in `WorkoutPlanDetailView`, wo `?? 0` für
    /// die reine Vorschau unkritisch ist).
    var goalSummary: String? {
        var parts: [String] = []

        if let targetSets, let targetReps {
            parts.append("\(targetSets) × \(targetReps)")
        } else if let targetReps {
            parts.append("× \(targetReps)")
        }

        if let targetWeightKg, targetWeightKg > 0 {
            let weightText: String = targetWeightKg.formatted(.number.precision(.fractionLength(0...1)))
            parts.append("\(weightText) kg")
        }

        if let targetDistanceMeters, targetDistanceMeters > 0 {
            let distanceKm: Double = targetDistanceMeters / 1000
            let distanceText: String = distanceKm.formatted(.number.precision(.fractionLength(0...1)))
            parts.append("\(distanceText) km")
        }

        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
