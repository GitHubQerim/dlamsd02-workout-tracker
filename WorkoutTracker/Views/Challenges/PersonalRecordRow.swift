import SwiftUI

/// Eine Zeile "Übungsname + Gewicht" für einen `PersonalRecord` - extrahiert
/// aus `RecentPersonalRecordsList`, damit die Rekord-Highlights auf dem
/// Workout-Abschluss-Screen (`WorkoutCompletionView`) dieselbe Darstellung
/// nutzen statt sie ein zweites Mal zu duplizieren.
struct PersonalRecordRow: View {
    let record: PersonalRecord

    var body: some View {
        HStack {
            Text(record.exerciseName)
                .font(DSFont.body)
                .foregroundStyle(DSColor.textPrimary)
            Spacer()
            Text("\(record.weightKg.formatted(.number.precision(.fractionLength(0...1)))) kg")
                .font(DSFont.caption)
                .foregroundStyle(DSColor.accent)
        }
    }
}
