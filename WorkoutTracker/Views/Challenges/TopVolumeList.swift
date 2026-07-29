import SwiftUI

/// Top-5-Übungen nach Trainingsvolumen (Σ Wdh. × Gewicht).
struct TopVolumeList: View {
    let exercises: [ExerciseVolume]

    var body: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSSpacing.s8) {
                Text("Top-5 nach Volumen")
                    .font(DSFont.label)
                    .foregroundStyle(DSColor.textSecondary)
                if exercises.isEmpty {
                    Text("Noch keine Daten")
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textTertiary)
                } else {
                    ForEach(exercises) { exercise in
                        HStack {
                            Text(exercise.exerciseName)
                                .font(DSFont.body)
                                .foregroundStyle(DSColor.textPrimary)
                            Spacer()
                            Text("\(Int(exercise.totalVolume)) kg")
                                .font(DSFont.caption)
                                .foregroundStyle(DSColor.textSecondary)
                        }
                    }
                }
            }
        }
    }
}
