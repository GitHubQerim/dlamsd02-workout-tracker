import Foundation
import SwiftData

extension WorkoutSession {
    /// Erkennt und persistiert neue Gewichts-Rekorde beim Session-Abschluss
    /// (ADR 0010) - nur für Kraft-Sessions, Cardio hat kein Gewicht/Wdh.-
    /// Äquivalent (ADR 0009). Zählt alle `SetLog`s dieser Session, unabhängig
    /// vom `isCompleted`-Häkchen (Konsistenz mit `previousAttempt()`, siehe
    /// ADR-0002-Nachtrag Phase D).
    func detectAndPersistPersonalRecords(in context: ModelContext) {
        guard activityType.usesSetLogs else { return }

        let bestThisSessionByExercise = Dictionary(grouping: setLogs, by: \.exerciseName)
            .compactMapValues { logs in logs.max(by: { $0.weightKg < $1.weightKg }) }

        for (exerciseName, bestSet) in bestThisSessionByExercise {
            let descriptor = FetchDescriptor<PersonalRecord>(
                predicate: #Predicate { $0.exerciseName == exerciseName },
                sortBy: [SortDescriptor(\.weightKg, order: .reverse)]
            )
            var limitedDescriptor = descriptor
            limitedDescriptor.fetchLimit = 1
            let currentBest = (try? context.fetch(limitedDescriptor))?.first

            guard currentBest == nil || bestSet.weightKg > currentBest!.weightKg else { continue }

            let record = PersonalRecord(
                exerciseName: exerciseName,
                weightKg: bestSet.weightKg,
                reps: bestSet.reps,
                achievedAt: startDate
            )
            record.session = self
            context.insert(record)
        }
    }
}
