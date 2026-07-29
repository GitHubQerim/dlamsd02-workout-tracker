import ActivityKit
import WidgetKit
import SwiftUI

/// Kompakte Live Activity (User-Vorgabe): Workout-Name, Satz-Fortschritt als
/// geneigte Parallelogramm-Leiste (`SetProgressBar`), Reps/Gewicht als ein
/// String, Countdown nur bei laufendem Pausentimer - bewusstes Ziel, dass
/// Lock Screen und Dynamic Island nicht überladen wirken.
struct WorkoutSessionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutSessionActivityAttributes.self) { context in
            lockScreenView(context: context)
                .containerBackground(for: .widget) { DSColor.surfaceBase }
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.workoutName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if let exerciseName = context.state.currentExerciseName {
                            Text(exerciseName)
                                .font(.subheadline.bold())
                                .lineLimit(1)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdownView(context: context, font: .caption.monospacedDigit())
                        .frame(width: 44)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(alignment: .top) {
                        if let description = context.state.compactSetDescription {
                            Text(description)
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            SetProgressBar(completionFlags: context.state.currentExerciseSetCompletionFlags, totalWidth: 80, height: 14)
                            SetProgressCaption(completionFlags: context.state.currentExerciseSetCompletionFlags)
                        }
                    }
                }
            } compactLeading: {
                if context.state.restTimerStartDate != nil {
                    countdownView(context: context, font: .caption2.monospacedDigit())
                        .frame(width: 30)
                } else {
                    Image(systemName: "dumbbell.fill")
                }
            } compactTrailing: {
                SetProgressBar(completionFlags: context.state.currentExerciseSetCompletionFlags, totalWidth: 32, height: 12)
            } minimal: {
                Image(systemName: "dumbbell.fill")
            }
        }
    }

    /// Nativer Countdown über `Text(timerInterval:)` - läuft ohne App-Wake
    /// im Widget-Prozess weiter (ADR 0003: Timestamps, kein Counter). `nil`
    /// bei fehlendem Pausentimer statt eine leere/falsche Zeit zu zeigen.
    @ViewBuilder
    private func countdownView(context: ActivityViewContext<WorkoutSessionActivityAttributes>, font: Font) -> some View {
        if let start = context.state.restTimerStartDate, let duration = context.state.restTimerDuration {
            Text(timerInterval: start...start.addingTimeInterval(duration), countsDown: true)
                .font(font)
                .multilineTextAlignment(.trailing)
        }
    }

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<WorkoutSessionActivityAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Text(context.state.workoutName)
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    SetProgressBar(completionFlags: context.state.currentExerciseSetCompletionFlags)
                    SetProgressCaption(completionFlags: context.state.currentExerciseSetCompletionFlags)
                }
            }
            if let exerciseName = context.state.currentExerciseName {
                Text(exerciseName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack {
                if let description = context.state.compactSetDescription {
                    Text(description)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                countdownView(context: context, font: .caption.monospacedDigit())
            }
        }
        .padding()
    }
}
