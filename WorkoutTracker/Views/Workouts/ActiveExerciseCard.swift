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

    @State private var previousAttempt: PreviousAttempt?
    /// Lokaler, unpersistierter UI-State - Default eingeklappt, damit eine
    /// Übung mit Warm-up-Sätzen die Karte nicht sofort überfüllt. Analog zu
    /// `expandedExerciseName` in `WorkoutSessionView` (auch nur lokaler State).
    @State private var isWarmupExpanded = false
    /// Von `.onDelete` gesetzt statt den Satz direkt zu entfernen - siehe
    /// `ConfirmRemovalModifier`. `SetLog` ist als `@Model`-Typ selbst
    /// `Hashable` (über `persistentModelID`), kein separates ID-Tracking nötig.
    @State private var pendingSetDeletion: SetLog?

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

                    if !section.warmupSets.isEmpty {
                        warmupSection
                    }

                    if !section.workSets.isEmpty {
                        columnHeader
                    }

                    ForEach(section.workSets) { setLog in
                        SwipeToDeleteRow(onDelete: { pendingSetDeletion = setLog }) {
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
                                onFieldFocusChange: onFieldFocusChange
                            )
                        }
                    }

                    // `section.target?.exercise` als Fallback: eine mitten in der
                    // Session zum Plan hinzugefügte Übung hat noch keine SetLogs
                    // (die Vorbefüllung läuft nur einmalig beim Session-Start in
                    // makeSession()) - ohne diesen Fallback gäbe es keinen UI-Weg,
                    // je ihren ersten Satz anzulegen, weil section.sets.first dann
                    // dauerhaft nil bleibt.
                    if let exercise = section.sets.first?.exercise ?? section.target?.exercise {
                        addSetBar(exercise: exercise)
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
        .confirmRemoval(title: "Satz entfernen?", pendingID: $pendingSetDeletion) { setLog in
            viewModel.deleteSet(setLog)
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

    /// Einklappbare Sektion für Warm-up-Sätze - Default eingeklappt (siehe
    /// `isWarmupExpanded`), zeigt dann einen kompakten, gestrichelten
    /// Zusammenfassungs-Chip statt der einzelnen Zeilen.
    private var warmupSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.s8) {
            Button {
                withAnimation(DSMotion.fast) { isWarmupExpanded.toggle() }
            } label: {
                HStack(spacing: DSSpacing.s4) {
                    Text("AUFWÄRMEN")
                        .tracking(1)
                    Text("· \(section.warmupSets.count)")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .rotationEffect(.degrees(isWarmupExpanded ? 90 : 0))
                }
                .font(DSFont.label)
                .foregroundStyle(DSColor.textTertiary)
                .padding(.horizontal, DSSpacing.s12)
                .frame(minHeight: DSSpacing.tapMin, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Aufwärmen, \(section.warmupSets.count) Sätze")
            .accessibilityHint(isWarmupExpanded ? "Doppeltippen zum Einklappen" : "Doppeltippen zum Ausklappen")

            if isWarmupExpanded {
                ForEach(section.warmupSets) { setLog in
                    SwipeToDeleteRow(onDelete: { pendingSetDeletion = setLog }) {
                        SetRow(
                            setLog: setLog,
                            onUpdate: { reps, weightKg in
                                viewModel.updateSet(setLog, reps: reps, weightKg: weightKg)
                            },
                            onToggle: {
                                withAnimation(DSMotion.expand) {
                                    viewModel.toggleSetCompletion(setLog)
                                    onSetToggled(setLog, section.name)
                                }
                            },
                            onFieldFocusChange: onFieldFocusChange,
                            style: .dashed
                        )
                    }
                }
            } else {
                warmupSummaryChip
            }
        }
    }

    private var warmupSummaryChip: some View {
        let summary = section.warmupSets
            .sorted { $0.setIndex < $1.setIndex }
            .map { "\($0.reps)×\($0.weightKg.formatted(.number.precision(.fractionLength(0...1)))) kg" }
            .joined(separator: " · ")
        return Text(summary)
            .font(DSFont.body)
            .foregroundStyle(DSColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DSSpacing.s12)
            .padding(.vertical, DSSpacing.s12)
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.tile, style: .continuous)
                    .strokeBorder(DSColor.borderStrong, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Aufwärmsätze eingeklappt: \(summary)")
    }

    /// Ersetzt den vorherigen einzelnen "Satz hinzufügen"-Button - drei
    /// gleich breite Optionen statt mehrerer verstreuter Add-Zeilen, damit
    /// die Liste bei spontanen Ergänzungen während des Trainings nicht
    /// überfüllt wirkt. "Superset" nur bei geplanten Workouts sichtbar -
    /// freies Training hat noch keine Verknüpfungs-Basis (siehe Superset-
    /// Feature-Plan). Nutzt `AddSetBarButton` statt `DSButton` - drei
    /// nebeneinander brauchen ein kompakteres Format, als `DSButton`s feste
    /// 52pt-Höhe/20pt-Padding hergeben (die für einzelne, volle Buttons
    /// gedacht sind, nicht für diese Leiste).
    private func addSetBar(exercise: Exercise) -> some View {
        let last = section.workSets.last
        return HStack(spacing: DSSpacing.s8) {
            AddSetBarButton(title: "Satz") {
                viewModel.addSet(
                    for: exercise,
                    suggestedReps: last?.reps ?? section.target?.targetReps,
                    suggestedWeightKg: last?.weightKg ?? section.target?.targetWeightKg
                )
            }
            AddSetBarButton(title: "Warm-up") {
                withAnimation(DSMotion.fast) { isWarmupExpanded = true }
                viewModel.addSet(for: exercise, isWarmup: true)
            }
            if viewModel.session.plan != nil {
                AddSetBarButton(title: "Superset") {
                    // TODO(Superset-Feature): Übungs-Auswahl-Sheet öffnen und
                    // viewModel.linkSuperset(...) aufrufen, siehe Feature-Plan.
                }
            }
        }
    }
}

/// Handgebaute Swipe-to-delete-Geste statt `List`+`.onDelete` - `List`
/// erwies sich in dieser Karte als unzuverlässig (zwei Anläufe: feste
/// Zeilenhöhe riss ab, dynamische Messung kollabierte auf Höhe 0), vermutlich
/// weil `ActiveExerciseCard`s komplette Body jede Sekunde vom Session-
/// Gesamt-Timer (`TimelineView`) neu ausgewertet wird und `List`s UIKit-
/// Unterbau mit dieser ständigen Neukonstruktion nicht robust umgeht. Ein
/// einfacher `VStack`/`ForEach` (wie vorher, bevor `List` eingeführt wurde)
/// hatte dieses Problem nie - deshalb bleibt die Struktur, und nur eine
/// eigene Drag-Geste ergänzt das Swipe-Verhalten, ohne `List`s Sizing-
/// Eigenheiten zu erben.
private struct SwipeToDeleteRow<Content: View>: View {
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var dragOffset: CGFloat = 0
    @State private var isRevealed = false

    private let actionWidth: CGFloat = 84

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Text("Löschen")
                    .font(DSFont.label)
                    .foregroundStyle(.white)
                    .frame(width: actionWidth)
                    .frame(maxHeight: .infinity)
            }
            .background(Color.red)
            // Nur sichtbar, sobald tatsächlich geswiped wird - sonst würde
            // der Button bei gestrichelten (transparenten) Warm-up-Zeilen
            // durch deren leere Mitte durchscheinen, auch in Ruheposition.
            .opacity(dragOffset < -1 ? 1 : 0)

            content()
                .offset(x: dragOffset)
                // `highPriorityGesture` statt `simultaneousGesture`: Letzteres
                // ließ Wisch UND den Toggle-Tap darunter unabhängig
                // voneinander feuern - ein Wisch übers Toggle hackte den Satz
                // versehentlich mit ab. `minimumDistance` sorgt dafür, dass
                // die Geste erst ab echter Bewegung "gewinnt"; ein reiner Tap
                // (keine Bewegung) erreicht diese Schwelle nie und lässt
                // Toggle/Tap-to-Edit-Felder unangetastet.
                .highPriorityGesture(
                    DragGesture(minimumDistance: 16)
                        .onChanged { value in
                            let translation = value.translation.width
                            guard abs(translation) > abs(value.translation.height) else { return }
                            let base: CGFloat = isRevealed ? -actionWidth : 0
                            dragOffset = min(0, max(base + translation, -actionWidth))
                        }
                        .onEnded { value in
                            let translation = value.translation.width
                            withAnimation(DSMotion.fast) {
                                if isRevealed {
                                    if translation > actionWidth / 2 {
                                        dragOffset = 0
                                        isRevealed = false
                                    } else {
                                        dragOffset = -actionWidth
                                    }
                                } else {
                                    if translation < -actionWidth / 2 {
                                        dragOffset = -actionWidth
                                        isRevealed = true
                                    } else {
                                        dragOffset = 0
                                    }
                                }
                            }
                        }
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.tile, style: .continuous))
    }
}

/// Kompakter Outline-Button für `addSetBar` - gleiche Farb-/Formsprache wie
/// `DSButton(variant: .outline)`, aber mit kleinerer Höhe/Schrift/Padding,
/// damit drei davon nebeneinander in eine Zeile passen. `DSButton` bleibt
/// bewusst unverändert (wird an vielen anderen Stellen in der App verwendet).
private struct AddSetBarButton: View {
    private static let height: CGFloat = 38

    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DSFont.label)
                .foregroundStyle(DSColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
                .frame(height: Self.height)
                .padding(.horizontal, DSSpacing.s8)
                // Capsule fasst nur den kompakten 38pt-Inhalt - erst DANACH
                // auf min. 44pt (Tap-Target-Minimum) erweitern, sonst würde
                // die zweite frame(minHeight:) die sichtbare Capsule selbst
                // auf 44pt aufblasen statt nur den unsichtbaren Tap-Bereich.
                .background(Capsule().strokeBorder(DSColor.borderStrong, lineWidth: 1))
                .frame(minHeight: DSSpacing.tapMin)
                .contentShape(Rectangle())
        }
        .buttonStyle(DSPressable())
    }
}
