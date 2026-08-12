import Foundation

/// Für neue, aus einem Plan gestartete Sätze: statt immer nur den reinen
/// Zielwert aus dem Plan zu übernehmen, schlägt dieser Helfer einen
/// editierbaren Startwert basierend auf der letzten abgeschlossenen Session
/// vor - +2,5kg, wenn die Ziel-Wiederholungen beim letzten Mal erreicht
/// oder übertroffen wurden, sonst dasselbe Gewicht wie damals (kein Minus
/// bei Nichterreichen - das bleibt bewusst dem Nutzer selbst überlassen,
/// siehe unten). Bewusst simpel, keine Trend-/Verlaufsanalyse über mehrere
/// Sessions hinweg - der Wert bleibt wie gehabt sofort editierbar, das ist
/// die eigentliche "Zustimmung" statt eines eigenen Bestätigungs-Dialogs.
enum ProgressiveOverloadSuggestion {
    static let increaseStepKg: Double = 2.5

    static func suggestedWeightKg(previousReps: Int, previousWeightKg: Double, targetReps: Int) -> Double {
        previousReps >= targetReps ? previousWeightKg + increaseStepKg : previousWeightKg
    }
}
