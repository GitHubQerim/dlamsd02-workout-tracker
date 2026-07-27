import SwiftUI
import SwiftData

/// Live-Session als `.fullScreenCover` (bewusst nicht `.sheet` - kein
/// versehentliches Wegwischen mitten im Satz). Gesamt-Timer läuft
/// wall-clock-basiert über `TimelineView` gegen `session.startDate`
/// (ADR 0003) - kein eigener Task/Timer im ViewModel.
///
/// Übungen erscheinen als Akkordeon: nur eine Übung ist gleichzeitig voll
/// aufgeklappt (Sätze editierbar), alle anderen nur als eingeklappte Zeile.
/// "Welche Übung ist aufgeklappt" ist reiner UI-State (`expandedExerciseName`)
/// - der sinnvolle Default ("erste nicht abgehakte Übung") kommt dagegen aus
/// dem ViewModel (`firstIncompleteExerciseName`), weil das echte Fachlogik
/// über die Satz-Daten ist, keine UI-Deko (siehe ADR 0004).
struct WorkoutSessionView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: WorkoutSessionViewModel

    @State private var isPresentingExercisePicker = false
    @State private var isPresentingFinishDialog = false
    @State private var expandedExerciseName: String?
    @FocusState private var focusedField: SetRowField?

    private var activeExerciseName: String? {
        expandedExerciseName ?? viewModel.firstIncompleteExerciseName
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                DSWashedScreen {
                    VStack(alignment: .leading, spacing: DSSpacing.sectionGap) {
                        TimelineView(.periodic(from: viewModel.session.startDate, by: 1)) { context in
                            DSStatTile(
                                label: "Gesamtzeit",
                                icon: "flame",
                                value: context.date.timeIntervalSince(viewModel.session.startDate).formattedClock
                            )
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
                .onChange(of: activeExerciseName) { _, newValue in
                    guard let newValue else { return }
                    withAnimation(DSMotion.base) {
                        scrollProxy.scrollTo(newValue, anchor: .top)
                    }
                }
            }
            .navigationTitle(viewModel.session.activityType.displayName)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Fertig") { focusedField = nil }
                }
            }
            .sheet(isPresented: $isPresentingExercisePicker) {
                ExercisePickerView { exercise in
                    viewModel.addSet(for: exercise)
                }
            }
            .fullScreenCover(item: restTimerBinding) { presentation in
                RestTimerView(
                    startDate: presentation.startDate,
                    duration: viewModel.restTimerDuration,
                    exerciseName: presentation.exerciseName,
                    onAdjust: viewModel.adjustRestDuration(by:),
                    onSkip: viewModel.skipRestTimer
                )
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

    /// Kleiner `Identifiable`-Wrapper für `.fullScreenCover(item:)` - der
    /// Übungsname wird an der Abhak-Stelle festgehalten (siehe `setRow`),
    /// weil dort bekannt ist, welche Übung gerade pausiert.
    private struct RestTimerPresentation: Identifiable {
        let startDate: Date
        let exerciseName: String
        var id: Date { startDate }
    }

    @State private var restTimerExerciseName: String = ""

    private var restTimerBinding: Binding<RestTimerPresentation?> {
        Binding(
            get: {
                guard let start = viewModel.restTimerStartDate else { return nil }
                return RestTimerPresentation(startDate: start, exerciseName: restTimerExerciseName)
            },
            set: { newValue in
                if newValue == nil { viewModel.skipRestTimer() }
            }
        )
    }

    @ViewBuilder
    private var strengthContent: some View {
        VStack(spacing: DSSpacing.cardGap) {
            ForEach(viewModel.exerciseSections, id: \.name) { section in
                if section.name == activeExerciseName {
                    activeExerciseCard(section)
                        .id(section.name)
                } else {
                    CollapsedExerciseRow(
                        name: section.name,
                        isComplete: viewModel.isExerciseComplete(section.name)
                    ) {
                        withAnimation(DSMotion.base) { expandedExerciseName = section.name }
                    }
                    .id(section.name)
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
    private func activeExerciseCard(_ section: (name: String, sets: [SetLog])) -> some View {
        let isComplete = viewModel.isExerciseComplete(section.name)

        DSCard(
            padding: DSSpacing.s16,
            background: isComplete ? DSColor.accentTrack.opacity(0.25) : DSColor.surfaceCard,
            borderColor: isComplete ? DSColor.accent : .clear
        ) {
            VStack(alignment: .leading, spacing: DSSpacing.stackGap) {
                HStack {
                    Text(section.name)
                        .font(DSFont.body)
                        .foregroundStyle(DSColor.textPrimary)
                    if isComplete {
                        DSIcon(name: "check", size: 16)
                            .foregroundStyle(DSColor.accent)
                    }
                }

                ForEach(section.sets) { setLog in
                    setRow(setLog, exerciseName: section.name)
                }

                if let exercise = section.sets.first?.exercise {
                    DSButton(title: "Satz hinzufügen", variant: .outline, fullWidth: true) {
                        let last = section.sets.last
                        viewModel.addSet(
                            for: exercise,
                            suggestedReps: last?.reps,
                            suggestedWeightKg: last?.weightKg
                        )
                    }
                }
            }
        }
        .animation(DSMotion.base, value: isComplete)
    }

    @ViewBuilder
    private func setRow(_ setLog: SetLog, exerciseName: String) -> some View {
        SetRow(
            setLog: setLog,
            onUpdate: { reps, weightKg in
                viewModel.updateSet(setLog, reps: reps, weightKg: weightKg)
            },
            onToggle: {
                viewModel.toggleSetCompletion(setLog)
                if setLog.isCompleted {
                    restTimerExerciseName = exerciseName
                    if viewModel.isExerciseComplete(exerciseName) {
                        withAnimation(DSMotion.base) {
                            expandedExerciseName = viewModel.firstIncompleteExerciseName
                        }
                    }
                }
            },
            focusedField: $focusedField
        )
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
