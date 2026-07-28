import SwiftUI
import SwiftData

/// Sheet-in-Sheet zur Workout-Auswahl beim Zusammenstellen eines
/// `WorkoutProgram`-Tages - parallel zu `ExercisePickerView`, aber listet
/// `Workout`s statt `Exercise`s. Bewusst kein Filter (anders als der
/// geplante Muskel-Filter in `ExercisePickerView`) - das ist ein separates,
/// nicht in diesem Feature enthaltenes Ticket.
struct WorkoutPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Workout.createdAt, order: .reverse) private var workouts: [Workout]

    let onSelect: (Workout) -> Void

    var body: some View {
        NavigationStack {
            DSWashedScreen {
                VStack(alignment: .leading, spacing: DSSpacing.sectionGap) {
                    if workouts.isEmpty {
                        Text("Noch keine Workouts angelegt")
                            .font(DSFont.body)
                            .foregroundStyle(DSColor.textSecondary)
                    } else {
                        VStack(spacing: DSSpacing.cardGap) {
                            ForEach(workouts) { workout in
                                Button {
                                    onSelect(workout)
                                    dismiss()
                                } label: {
                                    DSCard {
                                        HStack {
                                            VStack(alignment: .leading, spacing: DSSpacing.s4) {
                                                Text(workout.name)
                                                    .font(DSFont.body)
                                                    .foregroundStyle(DSColor.textPrimary)
                                                Text(workout.activityType.displayName)
                                                    .font(DSFont.caption)
                                                    .foregroundStyle(DSColor.textTertiary)
                                            }
                                            Spacer()
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Workout wählen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
    }
}
