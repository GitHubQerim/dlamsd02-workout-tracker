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
    @State private var isPresentingCompletion = false
    @State private var expandedExerciseName: String?
    /// Solange ein `SetValueField` fokussiert ist, sitzt dessen Tastatur-
    /// Toolbar (Quick-Adjust-Buttons) im selben Bereich wie die permanente
    /// `finishBar` (`.safeAreaInset(edge: .bottom)`) - beide überlappen sich
    /// sonst sichtbar. Blendet die Pille für diesen Zeitraum aus.
    @State private var isAnyValueFieldFocused = false
    /// Ob die große `RestTimerView` gerade explizit angezeigt wird - vom
    /// bloßen "läuft ein Pausen-Timer" (`viewModel.restTimerStartDate`)
    /// entkoppelt, damit eine neue Pause standardmäßig minimiert in der
    /// `finishBar` startet statt automatisch das Vollbild zu öffnen. Wird
    /// bei jedem neuen Satz-Abhaken in `handleSetToggled` zurückgesetzt.
    @State private var isRestTimerExpanded = false
    /// Fürs Haptic + den Zeilen-Puls, wenn eine Pause abläuft, während sie
    /// minimiert war (siehe `restTimerAutoSkipWatcher`). Explizit auf `true`
    /// gesetzt und nach der Puls-Animationsdauer wieder auf `false`
    /// zurückgesetzt - kein reines `.toggle()`, sonst bliebe der visuelle
    /// Puls nach dem ersten Ablauf-Event dauerhaft sichtbar.
    @State private var restExpiredPulseTrigger = false
    @Namespace private var expandNamespace

    private var activeExerciseName: String? {
        expandedExerciseName ?? viewModel.firstIncompleteExerciseName
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                DSWashedScreen {
                    VStack(alignment: .leading, spacing: DSSpacing.sectionGap) {
                        TimelineView(.periodic(from: viewModel.session.startDate, by: 1)) { context in
                            HStack(alignment: .sessionHeaderBaseline) {
                                Text(viewModel.displayTitle)
                                    .font(DSFont.score)
                                    .foregroundStyle(DSColor.textPrimary)
                                    .alignmentGuide(.sessionHeaderBaseline) { $0[.firstTextBaseline] }

                                Spacer()

                                VStack(alignment: .trailing, spacing: DSSpacing.s4) {
                                    HStack(spacing: 5) {
                                        DSIcon(name: "flame", size: 13)
                                            .foregroundStyle(DSColor.textSecondary)
                                        Text("Gesamtzeit")
                                            .font(DSFont.caption)
                                            .foregroundStyle(DSColor.textSecondary)
                                    }
                                    Text(context.date.timeIntervalSince(viewModel.session.startDate).formattedClock)
                                        .font(DSFont.score)
                                        .foregroundStyle(DSColor.textPrimary)
                                        .monospacedDigit()
                                        .alignmentGuide(.sessionHeaderBaseline) { $0[.firstTextBaseline] }
                                }
                            }
                        }

                        if viewModel.session.activityType.usesSetLogs {
                            strengthContent
                        } else {
                            cardioContent
                        }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    // TODO: Bleibt vorerst beim Ausblenden während Feld-Fokus
                    // (statt dauerhaft sichtbar) - ein Versuch, die Pille
                    // immer zu zeigen, kollidierte je nach Scroll-Position
                    // sichtbar mit der Tastatur-Toolbar (`SetValueField`s
                    // `.toolbar(.keyboard)`). Für den Pause-Fall bräuchte
                    // das eine eigene, nicht-kollidierende Darstellung (z.B.
                    // ein kleines Badge oben) statt einfach dieselbe Pille
                    // stehen zu lassen - noch offen.
                    if !isAnyValueFieldFocused {
                        finishBar
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .onChange(of: activeExerciseName) { _, newValue in
                    guard let newValue else { return }
                    withAnimation(DSMotion.base) {
                        scrollProxy.scrollTo(newValue, anchor: .top)
                    }
                }
            }
            // Muss unabhängig von `finishBar` dauerhaft aktiv bleiben (siehe
            // dortiger Kommentar) - läuft eine Pause exakt während ein
            // Eingabefeld fokussiert ist ab (finishBar dann nicht gemountet),
            // gäbe es sonst keinen beobachtbaren `onChange`-Übergang mehr und
            // Auto-Skip/Puls/Haptic würden nie feuern.
            .background(restTimerAutoSkipWatcher)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                    }
                    .accessibilityLabel("Schließen")
                }
            }
            .sheet(isPresented: $isPresentingExercisePicker) {
                ExercisePickerView { exercise in
                    viewModel.addSet(for: exercise)
                }
            }
            .sheet(isPresented: $isPresentingCompletion, onDismiss: { dismiss() }) {
                WorkoutCompletionView(viewModel: viewModel)
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
            // condition: nur beim Wechsel zu `true` feuern - der programmatische
            // Reset auf `false` (siehe restTimerAutoSkipWatcher) darf keine
            // zweite Haptic auslösen.
            .sensoryFeedback(.warning, trigger: restExpiredPulseTrigger) { _, newValue in newValue }
            .confirmationDialog("Training beenden?", isPresented: $isPresentingFinishDialog, titleVisibility: .visible) {
                Button("Speichern & beenden") {
                    Task {
                        await viewModel.finishSession()
                        isPresentingCompletion = true
                    }
                }
                Button("Verwerfen", role: .destructive) {
                    Task {
                        await viewModel.discardSession()
                        dismiss()
                    }
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

    /// Zeigt das `.fullScreenCover` nur, wenn zusätzlich zum laufenden
    /// Pausen-Timer auch explizit `isRestTimerExpanded` gesetzt ist - eine
    /// neue Pause startet also standardmäßig minimiert (siehe `finishBar`).
    private var restTimerBinding: Binding<RestTimerPresentation?> {
        Binding(
            get: {
                guard isRestTimerExpanded, let start = viewModel.restTimerStartDate else { return nil }
                return RestTimerPresentation(startDate: start, exerciseName: restTimerExerciseName)
            },
            set: { newValue in
                if newValue == nil {
                    isRestTimerExpanded = false
                    viewModel.skipRestTimer()
                }
            }
        )
    }

    /// Permanente schwebende Pille am unteren Bildschirmrand (Titel + Zeit +
    /// "Workout beenden"), über `.safeAreaInset(edge: .bottom)` eingehängt statt als
    /// `.overlay`, damit `DSWashedScreen`s interne ScrollView ihren
    /// Content-Inset automatisch anpasst und das letzte Akkordeon-Element
    /// nicht dauerhaft dahinter verschwindet. Gleiche Kapsel-Form wie die
    /// system-gerenderte Liquid-Glass-Tab-Bar (ADR 0005), aber im eigenen
    /// GreenDarkFitness-Look statt echtem Glas-Material - Content bleibt
    /// Content, keine neue Ausnahme von der ADR nötig.
    ///
    /// Sind wirklich alle Sätze/Segmente abgehakt, inverten Bar- und
    /// Button-Füllung (statt eines separaten Glow/Schimmer-Effekts) - dasselbe
    /// "Farbe zeigt Vollständigkeit"-Muster wie bei `ActiveExerciseCard`/
    /// `SetRow`/`CollapsedExerciseRow`, nur hier auf die permanente Pille
    /// übertragen. Label wechselt von "beenden" auf "abschließen", weil es ab
    /// diesem Punkt kein Abbruch mehr ist, sondern ein echter Abschluss.
    ///
    /// Läuft zusätzlich ein Pausen-Timer, übernimmt derselbe linke Bereich
    /// (Titel+Gesamtzeit) stattdessen einen großen, akzentfarbenen Countdown
    /// ("Pause"-Zustand) - kein zweites `TimelineView`, derselbe Tick treibt
    /// beides. `isComplete` hat dabei bewusst Vorrang vor "Pause": schließt
    /// der letzte Satz das Workout ab, während der Timer vom vorletzten Satz
    /// noch läuft (`WorkoutSessionViewModel.toggleSetCompletion` bricht
    /// diesen Timer nicht ab), zeigt die Pille sofort "abschließen" statt
    /// "Pause" - der verwaiste Timer läuft im Hintergrund trotzdem sauber
    /// aus (siehe `restTimerAutoSkipWatcher`, bewusst ohne `!isComplete`-
    /// Guard dort).
    @ViewBuilder
    private var finishBar: some View {
        let isComplete = viewModel.isWorkoutComplete
        let isResting = viewModel.isRestTimerRunning && !isComplete

        TimelineView(.periodic(from: viewModel.session.startDate, by: 1)) { context in
            let restStart = viewModel.restTimerStartDate
            let restRemaining = restStart.map { max(0, viewModel.restTimerDuration - context.date.timeIntervalSince($0)) }

            HStack(spacing: DSSpacing.stackGap) {
                HStack(spacing: DSSpacing.stackGap) {
                    VStack(alignment: .leading, spacing: 2) {
                        if isResting {
                            Text("Pause")
                                .font(DSFont.caption)
                                .foregroundStyle(DSColor.accent)
                            Text((restRemaining ?? 0).formattedClock)
                                .font(DSFont.metric)
                                .foregroundStyle(DSColor.accent)
                                .monospacedDigit()
                        } else {
                            Text(viewModel.displayTitle)
                                .font(DSFont.body)
                                .foregroundStyle(isComplete ? DSColor.textOnInvert : DSColor.textPrimary)
                                .lineLimit(1)
                            Text(context.date.timeIntervalSince(viewModel.session.startDate).formattedClock)
                                .font(DSFont.caption)
                                .foregroundStyle(isComplete ? DSColor.textOnInvert.opacity(0.7) : DSColor.textSecondary)
                                .monospacedDigit()
                        }
                    }
                    .accessibilityElement(children: .combine)

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    guard isResting else { return }
                    isRestTimerExpanded = true
                }
                .accessibilityAddTraits(isResting ? .isButton : [])
                .accessibilityHint(isResting ? "Doppeltippen, um den Pausen-Timer zu öffnen" : "")

                Button(isComplete ? "Workout abschließen" : "Workout beenden") {
                    isPresentingFinishDialog = true
                }
                .font(DSFont.body)
                .foregroundStyle(isComplete ? DSColor.textPrimary : DSColor.textOnInvert)
                .padding(.horizontal, DSSpacing.s16)
                .frame(minHeight: 40)
                .background(isComplete ? DSColor.surfaceCard : DSColor.accent, in: Capsule())
            }
            .padding(.horizontal, DSSpacing.s16)
            .frame(minHeight: 56)
            .background(isComplete ? DSColor.accent : DSColor.surfaceCard, in: Capsule())
            .overlay(Capsule().stroke(isResting ? DSColor.accent : DSColor.borderStrong, lineWidth: isResting ? 2 : 1))
            .padding(.horizontal, DSSpacing.screenGutter)
            .padding(.bottom, DSSpacing.s8)
            .animation(DSMotion.base, value: isComplete)
            .animation(DSMotion.base, value: isResting)
        }
    }

    /// Unsichtbarer, IMMER gemounteter Beobachter für den Pausen-Ablauf -
    /// bewusst getrennt von `finishBar` (die bei Feld-Fokus ausgeblendet
    /// wird, siehe dortiger Kommentar), damit Auto-Skip/Puls/Haptic auch
    /// dann feuern, wenn die Pause exakt während einer Zahlen-Eingabe
    /// abläuft. `finishBar` behält ihre eigene, rein darstellende
    /// Restzeit-Berechnung für den Countdown-Text.
    private var restTimerAutoSkipWatcher: some View {
        TimelineView(.periodic(from: viewModel.session.startDate, by: 1)) { context in
            let restStart = viewModel.restTimerStartDate
            let restRemaining = restStart.map { max(0, viewModel.restTimerDuration - context.date.timeIntervalSince($0)) }
            let isExpired = restStart != nil && (restRemaining ?? 1) <= 0

            Color.clear
                .onChange(of: isExpired) { _, expired in
                    guard expired, !isRestTimerExpanded else { return }
                    viewModel.skipRestTimer()
                    // Kein reines .toggle() (ADR-Nachtrag): `true` dann nach
                    // der Puls-Animationsdauer explizit zurück auf `false` -
                    // sonst bleibt der Akzent-Rahmen auf der SetRow nach dem
                    // ersten Ablauf-Event dauerhaft sichtbar, statt kurz
                    // aufzublinken (repeatCount-Animation läuft aus, hält
                    // aber beim zuletzt gesetzten Wert).
                    restExpiredPulseTrigger = true
                    Task {
                        try? await Task.sleep(for: .milliseconds(750))
                        restExpiredPulseTrigger = false
                    }
                }
        }
    }

    @ViewBuilder
    private var strengthContent: some View {
        VStack(spacing: DSSpacing.cardGap) {
            ForEach(viewModel.exerciseSections) { section in
                if section.name == activeExerciseName {
                    ActiveExerciseCard(
                        section: section,
                        viewModel: viewModel,
                        namespace: expandNamespace,
                        onSetToggled: handleSetToggled,
                        onFieldFocusChange: { focused in
                            withAnimation(DSMotion.base) {
                                isAnyValueFieldFocused = focused
                            }
                        },
                        pulseTrigger: restExpiredPulseTrigger
                    )
                    .id(section.name)
                } else {
                    CollapsedExerciseRow(
                        name: section.name,
                        isComplete: viewModel.isExerciseComplete(section.name),
                        namespace: expandNamespace
                    ) {
                        withAnimation(DSMotion.expand) { expandedExerciseName = section.name }
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

    /// Wird von `ActiveExerciseCard` nach jedem Satz-Toggle aufgerufen -
    /// verwaltet den Übungsnamen für den Pausen-Timer-Kontext und die
    /// Auto-Advance-Logik, weil `expandedExerciseName`/`restTimerExerciseName`
    /// hier in `WorkoutSessionView`, nicht in der Karte, als State leben.
    private func handleSetToggled(_ setLog: SetLog, exerciseName: String) {
        guard setLog.isCompleted else { return }
        restTimerExerciseName = exerciseName
        isRestTimerExpanded = false
        if viewModel.isExerciseComplete(exerciseName) {
            withAnimation(DSMotion.expand) {
                expandedExerciseName = viewModel.firstIncompleteExerciseName
            }
        }
    }

    /// Flache, nicht-akkordierende Liste - Segmente sind typischerweise
    /// wenige (2-4) und anders als Kraft's Übung→Sätze nicht weiter
    /// verschachtelt, daher kein Accordion/`matchedGeometryEffect` nötig.
    @ViewBuilder
    private var cardioContent: some View {
        VStack(spacing: DSSpacing.cardGap) {
            ForEach(viewModel.segmentSections) { segmentLog in
                segmentRow(segmentLog)
            }
        }

        if viewModel.session.plan == nil {
            DSButton(title: "Segment hinzufügen", icon: "flame", variant: .outline, fullWidth: true) {
                viewModel.addSegment(label: "Segment \(viewModel.segmentSections.count + 1)")
            }
        }

        DSCard {
            Stepper(value: Binding(
                get: { viewModel.session.averageHeartRate ?? 0 },
                set: { viewModel.updateAverageHeartRate($0) }
            ), in: 0...220) {
                Text("Ø Puls: \(viewModel.session.averageHeartRate ?? 0)")
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.textPrimary)
            }
        }
    }

    @ViewBuilder
    private func segmentRow(_ segmentLog: SegmentLog) -> some View {
        DSCard(background: segmentLog.isCompleted ? DSColor.accentTrack.opacity(0.4) : DSColor.surfaceCard) {
            VStack(alignment: .leading, spacing: DSSpacing.stackGap) {
                HStack {
                    Text(segmentLog.label)
                        .font(DSFont.body)
                        .foregroundStyle(DSColor.textPrimary)
                    Spacer()
                    Button(action: { viewModel.toggleSegmentCompletion(segmentLog) }) {
                        DSIcon(name: "check", size: 18)
                            .foregroundStyle(segmentLog.isCompleted ? DSColor.accent : DSColor.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(segmentLog.label) abhaken")
                    .accessibilityValue(segmentLog.isCompleted ? "erledigt" : "offen")
                }

                if let fieldOptions = viewModel.session.activityType.cardioFieldOptions, fieldOptions.showsDistance {
                    Stepper(value: Binding(
                        get: { segmentLog.distanceMeters ?? 0 },
                        set: { viewModel.updateSegment(segmentLog, distanceMeters: $0, durationSeconds: segmentLog.durationSeconds) }
                    ), in: 0...100_000, step: 100) {
                        Text("Distanz: \((segmentLog.distanceMeters ?? 0) / 1000, specifier: "%.1f") km")
                            .font(DSFont.caption)
                            .foregroundStyle(DSColor.textSecondary)
                    }
                }

                if let fieldOptions = viewModel.session.activityType.cardioFieldOptions, fieldOptions.showsDuration {
                    DSWheelPickerField(
                        label: "Dauer",
                        value: Int((segmentLog.durationSeconds ?? 0) / 60),
                        options: Array(0...180),
                        displayText: { "\($0) Min." }
                    ) { newValue in
                        viewModel.updateSegment(segmentLog, distanceMeters: segmentLog.distanceMeters, durationSeconds: Double(newValue) * 60)
                    }
                }
            }
        }
    }
}

/// Richtet den Session-Titel links an der Baseline der GROSSEN Zeit-Zahl
/// rechts aus (nicht am kleinen "Gesamtzeit"-Label darüber). `.firstTextBaseline`
/// am äußeren HStack würde sich sonst an der ERSTEN Zeile des rechten VStack
/// orientieren - das ist das Label, nicht die Zeit. Beide Texte nutzen
/// denselben `DSFont.score`, daher erzwingt das hier die exakte
/// Baseline-Gleichheit statt sich auf zufällig passende Zeilenhöhen von
/// `.center`/`.bottom` zu verlassen.
private struct SessionHeaderBaseline: AlignmentID {
    static func defaultValue(in context: ViewDimensions) -> CGFloat {
        context[.firstTextBaseline]
    }
}

private extension VerticalAlignment {
    static let sessionHeaderBaseline = VerticalAlignment(SessionHeaderBaseline.self)
}
