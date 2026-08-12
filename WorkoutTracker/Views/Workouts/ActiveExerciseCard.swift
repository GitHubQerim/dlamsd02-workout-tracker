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
    var namespace: Namespace.ID
    let onSetToggled: (SetLog, String) -> Void
    /// Durchgereicht an jede `SetRow`, siehe `SetValueField.onFocusChange`.
    var onFieldFocusChange: ((Bool) -> Void)? = nil
    /// Durchgereicht an jede `SetRow`, siehe deren `pulseTrigger`-Doc-Kommentar.
    var pulseTrigger: Bool = false

    @State private var previousAttempt: PreviousAttempt?

    private var isComplete: Bool { viewModel.isExerciseComplete(section.name) }
    private var nextSetID: PersistentIdentifier? { viewModel.nextIncompleteSetID(in: section.name) }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.stackGap) {
            DSCard(
                padding: DSSpacing.s16,
                background: isComplete ? DSColor.accentTrack.opacity(0.4) : DSColor.surfaceCard
            ) {
                VStack(alignment: .leading, spacing: DSSpacing.stackGap) {
                    HStack {
                        Text(section.name)
                            .font(DSFont.body)
                            .foregroundStyle(DSColor.textPrimary)
                            .matchedGeometryEffect(id: "\(section.name)-title", in: namespace)
                        if isComplete {
                            DSIcon(name: "check", size: 16)
                                .foregroundStyle(DSColor.accent)
                                .accessibilityHidden(true)
                        }
                    }
                    // Reiner Anzeigetext (Name + Häkchen-Icon), keine Controls
                    // - .combine reduziert das auf einen sinnvollen
                    // VoiceOver-Stopp statt mehrerer Fragmente (siehe gleiche
                    // Begründung in PreviousSessionComparisonCard). Das Ziel
                    // (targetSets×targetReps) steht bewusst nicht mehr hier -
                    // "Wdh. × Gewicht (kg)" im Spaltenkopf sagt bereits, was
                    // eingetragen wird, eine zusätzliche Ziel-Zeile war
                    // redundant.
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
                                // Beide Mutationen (isCompleted-Flip UND ggf. Auto-Advance
                                // auf die nächste Übung) unter derselben expliziten
                                // Transaktion, damit Farbwechsel und Akkordeon-Wechsel
                                // dieselbe Kurve/Dauer teilen statt zu konkurrieren (siehe
                                // Kommentar am entfernten .animation(value: isComplete)
                                // weiter unten in dieser Datei).
                                withAnimation(DSMotion.expand) {
                                    viewModel.toggleSetCompletion(setLog)
                                    onSetToggled(setLog, section.name)
                                }
                            },
                            isNextUp: setLog.persistentModelID == nextSetID,
                            previousSet: previousAttempt?.sets.first(where: { $0.setIndex == setLog.setIndex }),
                            onFieldFocusChange: onFieldFocusChange,
                            pulseTrigger: pulseTrigger
                        )
                    }

                    // `section.target?.exercise` als Fallback: eine mitten in der
                    // Session zum Plan hinzugefügte Übung hat noch keine SetLogs
                    // (die Vorbefüllung läuft nur einmalig beim Session-Start in
                    // makeSession()) - ohne diesen Fallback gäbe es keinen UI-Weg,
                    // je ihren ersten Satz anzulegen, weil section.sets.first dann
                    // dauerhaft nil bleibt.
                    if let exercise = section.sets.first?.exercise ?? section.target?.exercise {
                        DSButton(title: "Satz hinzufügen", variant: .outline, fullWidth: true) {
                            let last = section.sets.last
                            viewModel.addSet(
                                for: exercise,
                                suggestedReps: last?.reps ?? section.target?.targetReps,
                                suggestedWeightKg: last?.weightKg ?? section.target?.targetWeightKg
                            )
                        }
                    }
                }
            }
            .matchedGeometryEffect(id: section.name, in: namespace)

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
            Text("Nr.").frame(minWidth: SetRowLayout.badge)
            Text("Wdh. × Gewicht (kg)")
                .frame(maxWidth: .infinity, alignment: .center)
            Text("Abschließen")
                .frame(minWidth: SetRowLayout.toggle, alignment: .center)
                .multilineTextAlignment(.center)
        }
        .font(DSFont.tableHeader)
        .foregroundStyle(DSColor.textTertiary)
        .padding(.horizontal, DSSpacing.s12)
        .accessibilityHidden(true)
    }
}
