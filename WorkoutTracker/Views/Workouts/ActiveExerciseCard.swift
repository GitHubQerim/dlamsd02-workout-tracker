import SwiftUI
import SwiftData

/// Die voll aufgeklappte, aktive Übung im Session-Akkordeon. Eigene View
/// (statt `@ViewBuilder`-Methode wie zuvor) - das gibt ihr eine stabile
/// SwiftUI-Identität über `.id(section.name)` im aufrufenden `ForEach`, was
/// hier zwingend nötig ist: `WorkoutSessionView`s Gesamt-Timer läuft über
/// `TimelineView(.periodic(from:by: 1))` und wertet dadurch den kompletten
/// Screen-Body jede Sekunde neu aus. Ohne eigene Identität würde `.task(id:)`
/// unten den "Letztes Mal"-Fetch bei jedem Sekunden-Tick erneut auslösen
/// statt nur beim tatsächlichen Übungswechsel.
struct ActiveExerciseCard: View {
    let section: ExerciseSection
    let viewModel: WorkoutSessionViewModel
    var focusedField: FocusState<SetRowField?>.Binding
    let onSetToggled: (SetLog, String) -> Void

    @State private var previousAttempt: PreviousAttempt?

    private var isComplete: Bool { viewModel.isExerciseComplete(section.name) }
    private var nextSetID: PersistentIdentifier? { viewModel.nextIncompleteSetID(in: section.name) }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.stackGap) {
            DSCard(
                padding: DSSpacing.s16,
                background: isComplete ? DSColor.accentTrack.opacity(0.25) : DSColor.surfaceCard,
                borderColor: isComplete ? DSColor.accent : .clear
            ) {
                VStack(alignment: .leading, spacing: DSSpacing.stackGap) {
                    HStack {
                        VStack(alignment: .leading, spacing: DSSpacing.s4) {
                            Text(section.name)
                                .font(DSFont.body)
                                .foregroundStyle(DSColor.textPrimary)
                            if let goal = section.target?.goalSummary {
                                Text("Ziel: \(goal)")
                                    .font(DSFont.caption)
                                    .foregroundStyle(DSColor.textSecondary)
                            }
                        }
                        if isComplete {
                            DSIcon(name: "check", size: 16)
                                .foregroundStyle(DSColor.accent)
                                .accessibilityHidden(true)
                        }
                    }
                    // Reiner Anzeigetext (Name + Ziel + Häkchen-Icon), keine
                    // Controls - .combine reduziert das auf einen sinnvollen
                    // VoiceOver-Stopp statt mehrerer Fragmente (siehe gleiche
                    // Begründung in PreviousSessionComparisonCard).
                    .accessibilityElement(children: .combine)
                    .accessibilityValue(isComplete ? "vollständig abgehakt" : "")

                    if !section.sets.isEmpty {
                        columnHeader
                    }

                    ForEach(section.sets) { setLog in
                        SetRow(
                            setLog: setLog,
                            onUpdate: { reps, weightKg in
                                viewModel.updateSet(setLog, reps: reps, weightKg: weightKg)
                            },
                            onToggle: {
                                viewModel.toggleSetCompletion(setLog)
                                onSetToggled(setLog, section.name)
                            },
                            focusedField: focusedField,
                            isNextUp: setLog.persistentModelID == nextSetID
                        )
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

            if let previousAttempt {
                PreviousSessionComparisonCard(attempt: previousAttempt)
            }
        }
        .task(id: section.name) {
            previousAttempt = viewModel.previousAttempt(for: section.name)
        }
    }

    /// Rein dekorativ - jede `SetRow` trägt bereits ihre eigenen präzisen
    /// VoiceOver-Labels, der Header wäre für Screenreader ein redundanter,
    /// nicht-interaktiver Stopp.
    private var columnHeader: some View {
        HStack(spacing: DSSpacing.stackGap) {
            Color.clear.frame(width: SetRowLayout.badge)
            HStack(spacing: DSSpacing.s8) {
                Text("Wdh.").frame(minWidth: SetRowLayout.repsMin)
                Text("×").opacity(0)
                Text("Gewicht").frame(minWidth: SetRowLayout.weightMin)
            }
            Spacer(minLength: 0)
            Color.clear.frame(width: SetRowLayout.toggle)
        }
        .font(DSFont.caption)
        .foregroundStyle(DSColor.textTertiary)
        .padding(.horizontal, DSSpacing.s12)
        .accessibilityHidden(true)
    }
}
