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
    @ViewBuilder
    private var finishBar: some View {
        let isComplete = viewModel.isWorkoutComplete

        TimelineView(.periodic(from: viewModel.session.startDate, by: 1)) { context in
            HStack(spacing: DSSpacing.stackGap) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.displayTitle)
                        .font(DSFont.body)
                        .foregroundStyle(isComplete ? DSColor.textOnInvert : DSColor.textPrimary)
                        .lineLimit(1)
                    Text(context.date.timeIntervalSince(viewModel.session.startDate).formattedClock)
                        .font(DSFont.caption)
                        .foregroundStyle(isComplete ? DSColor.textOnInvert.opacity(0.7) : DSColor.textSecondary)
                        .monospacedDigit()
                }
                .accessibilityElement(children: .combine)

                Spacer()

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
            .overlay(Capsule().stroke(DSColor.borderStrong, lineWidth: 1))
            .padding(.horizontal, DSSpacing.screenGutter)
            .padding(.bottom, DSSpacing.s8)
            .animation(DSMotion.base, value: isComplete)
        }
    }

    @ViewBuilder
    private var strengthContent: some View {
        VStack(spacing: DSSpacing.cardGap) {
            ForEach(viewModel.sessionRows) { row in
                switch row {
                case .single(let section):
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
                            }
                        )
                        .id(section.name)
                    } else {
                        CollapsedExerciseRow(
                            name: section.name,
                            isComplete: viewModel.isExerciseComplete(section.name),
                            namespace: expandNamespace,
                            action: {
                                withAnimation(DSMotion.expand) { expandedExerciseName = section.name }
                            }
                        )
                        .id(section.name)
                    }
                case .superset(let primary, let attached):
                    // Eine verschmolzene Card gilt als "aktiv", sobald EINE
                    // der beiden Übungen die aktive ist - Tippen auf
                    // irgendeine Seite klappt das ganze Paar auf.
                    if primary.name == activeExerciseName || attached.name == activeExerciseName {
                        MergedExerciseCard(
                            primary: primary,
                            attached: attached,
                            viewModel: viewModel,
                            namespace: expandNamespace,
                            onSetToggled: handleSetToggled,
                            onFieldFocusChange: { focused in
                                withAnimation(DSMotion.base) {
                                    isAnyValueFieldFocused = focused
                                }
                            }
                        )
                        .id(primary.name)
                    } else {
                        VStack(spacing: DSSpacing.cardGap) {
                            CollapsedExerciseRow(
                                name: primary.name,
                                isComplete: viewModel.isExerciseComplete(primary.name),
                                namespace: expandNamespace
                            ) {
                                withAnimation(DSMotion.expand) { expandedExerciseName = primary.name }
                            }
                            CollapsedExerciseRow(
                                name: attached.name,
                                isComplete: viewModel.isExerciseComplete(attached.name),
                                namespace: expandNamespace
                            ) {
                                withAnimation(DSMotion.expand) { expandedExerciseName = primary.name }
                            }
                        }
                        .id(primary.name)
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

    /// Wird von `ActiveExerciseCard`/`MergedExerciseCard` nach jedem
    /// Satz-Toggle aufgerufen - verwaltet den Übungsnamen für den
    /// Pausen-Timer-Kontext und die Auto-Advance-Logik, weil
    /// `expandedExerciseName`/`restTimerExerciseName` hier in
    /// `WorkoutSessionView`, nicht in der Karte, als State leben. Bei einer
    /// Superset-Übung erst weiterspringen, wenn AUCH die Partner-Übung
    /// komplett ist - sonst würde der Accordion von einem verschmolzenen
    /// Paar wegspringen, während die andere Hälfte noch offene Sätze hat.
    private func handleSetToggled(_ setLog: SetLog, exerciseName: String) {
        guard setLog.isCompleted else { return }
        restTimerExerciseName = exerciseName
        guard viewModel.isExerciseComplete(exerciseName) else { return }

        let row = viewModel.sessionRows.first { row in
            switch row {
            case .single(let section): section.name == exerciseName
            case .superset(let primary, let attached): primary.name == exerciseName || attached.name == exerciseName
            }
        }
        let bothHalvesComplete: Bool = {
            guard case .superset(let primary, let attached) = row else { return true }
            return viewModel.isExerciseComplete(primary.name) && viewModel.isExerciseComplete(attached.name)
        }()
        guard bothHalvesComplete else { return }

        withAnimation(DSMotion.expand) {
            expandedExerciseName = viewModel.firstIncompleteExerciseName
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
