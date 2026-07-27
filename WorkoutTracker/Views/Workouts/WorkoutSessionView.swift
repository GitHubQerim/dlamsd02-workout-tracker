import SwiftUI
import SwiftData

/// Live-Session als `.fullScreenCover` (bewusst nicht `.sheet` - kein
/// versehentliches Wegwischen mitten im Satz). Gesamt-Timer läuft
/// wall-clock-basiert über `TimelineView` gegen `session.startDate`
/// (ADR 0003) - kein eigener Task/Timer im ViewModel.
struct WorkoutSessionView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: WorkoutSessionViewModel

    @State private var isPresentingExercisePicker = false
    @State private var isPresentingFinishDialog = false

    var body: some View {
        NavigationStack {
            DSWashedScreen {
                VStack(alignment: .leading, spacing: DSSpacing.sectionGap) {
                    TimelineView(.periodic(from: viewModel.session.startDate, by: 1)) { context in
                        DSStatTile(
                            label: "Gesamtzeit",
                            icon: "flame",
                            value: context.date.timeIntervalSince(viewModel.session.startDate).formattedClock
                        )
                    }

                    if let restStart = viewModel.restTimerStartDate {
                        RestTimerBanner(startDate: restStart, duration: viewModel.restTimerDuration) {
                            viewModel.skipRestTimer()
                        }
                    }

                    if viewModel.session.activityType.usesSetLogs {
                        strengthContent
                    } else {
                        cardioContent
                    }

                    DSButton(title: "Training beenden", fullWidth: true) {
                        isPresentingFinishDialog = true
                    }
                }
            }
            .navigationTitle(viewModel.session.activityType.displayName)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
            .sheet(isPresented: $isPresentingExercisePicker) {
                ExercisePickerView { exercise in
                    viewModel.addSet(for: exercise)
                }
            }
            .confirmationDialog("Training beenden?", isPresented: $isPresentingFinishDialog, titleVisibility: .visible) {
                Button("Speichern & beenden") {
                    viewModel.finishSession()
                    dismiss()
                }
                Button("Verwerfen", role: .destructive) {
                    viewModel.discardSession()
                    dismiss()
                }
                Button("Weiter trainieren", role: .cancel) {}
            }
        }
    }

    @ViewBuilder
    private var strengthContent: some View {
        VStack(spacing: DSSpacing.cardGap) {
            ForEach(viewModel.exerciseSections, id: \.name) { section in
                DSCard {
                    VStack(alignment: .leading, spacing: DSSpacing.stackGap) {
                        Text(section.name)
                            .font(DSFont.body)
                            .foregroundStyle(DSColor.textPrimary)

                        ForEach(section.sets) { setLog in
                            setLogRow(setLog)
                        }
                    }
                }
            }
        }

        if viewModel.session.plan == nil {
            DSButton(title: "Übung hinzufügen", icon: "dumbbell", variant: .outline, fullWidth: true) {
                isPresentingExercisePicker = true
            }
        }
    }

    @ViewBuilder
    private func setLogRow(_ setLog: SetLog) -> some View {
        HStack(spacing: DSSpacing.stackGap) {
            Button {
                viewModel.toggleSetCompletion(setLog)
            } label: {
                DSIcon(name: setLog.isCompleted ? "check" : "rotate-ccw")
                    .foregroundStyle(setLog.isCompleted ? DSColor.accent : DSColor.textTertiary)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Satz \(setLog.setIndex + 1), \(setLog.exerciseName)")
            .accessibilityValue(setLog.isCompleted ? "erledigt" : "offen")
            .accessibilityHint("Doppeltippen zum Abhaken")
            .accessibilityAddTraits(setLog.isCompleted ? [.isSelected] : [])

            Text("Satz \(setLog.setIndex + 1)")
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
                .accessibilityHidden(true)

            Spacer()

            Stepper(value: Binding(
                get: { setLog.reps },
                set: { viewModel.updateSet(setLog, reps: $0, weightKg: setLog.weightKg) }
            ), in: 0...50) {
                Text("\(setLog.reps) Wdh.")
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textPrimary)
            }

            Stepper(value: Binding(
                get: { setLog.weightKg },
                set: { viewModel.updateSet(setLog, reps: setLog.reps, weightKg: $0) }
            ), in: 0...300, step: 2.5) {
                Text("\(setLog.weightKg, specifier: "%.1f") kg")
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textPrimary)
            }
        }
    }

    @ViewBuilder
    private var cardioContent: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSSpacing.stackGap) {
                Stepper(value: Binding(
                    get: { viewModel.session.distanceMeters ?? 0 },
                    set: { viewModel.updateCardioMetrics(distanceMeters: $0, averageHeartRate: viewModel.session.averageHeartRate) }
                ), in: 0...100_000, step: 100) {
                    Text("Distanz: \((viewModel.session.distanceMeters ?? 0) / 1000, specifier: "%.1f") km")
                        .font(DSFont.body)
                        .foregroundStyle(DSColor.textPrimary)
                }

                Stepper(value: Binding(
                    get: { viewModel.session.averageHeartRate ?? 0 },
                    set: { viewModel.updateCardioMetrics(distanceMeters: viewModel.session.distanceMeters, averageHeartRate: $0) }
                ), in: 0...220) {
                    Text("Ø Puls: \(viewModel.session.averageHeartRate ?? 0)")
                        .font(DSFont.body)
                        .foregroundStyle(DSColor.textPrimary)
                }
            }
        }
    }
}
