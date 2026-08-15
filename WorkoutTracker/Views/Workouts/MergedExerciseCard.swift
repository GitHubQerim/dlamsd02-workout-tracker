import SwiftUI
import SwiftData

/// Zwei per Superset verknüpfte Übungen als eine verschmolzene Card
/// (`WorkoutSessionViewModel.SessionRow.superset`) - primäre Übung solide,
/// angehängte Übung gestrichelt (nicht geringerwertig, nur "die angehängte
/// Seite", siehe `SetRowStyle`-Dokumentation).
///
/// Rundenweise interleaved statt zwei gestapelter Blöcke: pro Runde der
/// primären Übung folgt direkt die passende Runde der angehängten Übung
/// (gleicher `setIndex`), mit einer kleinen Kette dazwischen - entspricht,
/// wie ein Supersatz tatsächlich trainiert wird (Runde für Runde im
/// Wechsel, nicht erst alle Sätze der einen Übung, dann alle der anderen).
/// Existiert für eine Runde noch keine angehängte Übung, erscheint dort NUR
/// bei der gerade aktiven Runde ein kompakter "+ Supersatz"-Button - so
/// muss die angehängte Übung nicht im Voraus mit derselben Satzanzahl
/// angelegt werden, sie wächst Runde für Runde mit.
struct MergedExerciseCard: View {
    let primary: ExerciseSection
    let attached: ExerciseSection
    let viewModel: WorkoutSessionViewModel
    var namespace: Namespace.ID
    let onSetToggled: (SetLog, String) -> Void
    var onFieldFocusChange: ((Bool) -> Void)? = nil

    @State private var pendingSetDeletion: SetLog?
    /// Bestätigungs-Dialog vorm Entkoppeln - `unlinkSuperset` löscht keine
    /// Sätze, die angehängte Übung läuft danach einfach als eigenständige
    /// Übung mit ihren bisherigen Sätzen weiter. Das steht auch explizit im
    /// Dialog-Text, damit klar ist: nichts geht verloren.
    @State private var isPresentingUnlinkConfirmation = false
    /// Separater Pending-State für den SONDERFALL "letzter Satz der
    /// angehängten Übung wird weggewischt" - ohne das würde die Runde direkt
    /// in den "+ Supersatz"-Zustand fallen (siehe `roundView`), obwohl der
    /// Supersatz als Ganzes noch verknüpft bleibt. Das Löschen dieses einen
    /// Satzes bündelt hier stattdessen Set-Löschung UND Entkoppeln in einer
    /// Bestätigung, damit die angehängte Übung danach wieder eine normale,
    /// eigenständige Übung ist statt eines leeren "+ Supersatz"-Platzhalters.
    @State private var pendingLastAttachedSetRemoval: SetLog?

    private var isComplete: Bool {
        viewModel.isExerciseComplete(primary.name) && viewModel.isExerciseComplete(attached.name)
    }

    /// Die Runde, bei der (falls die angehängte Übung dort noch fehlt) der
    /// "+ Supersatz"-Button erscheint - erste offene Runde der primären
    /// Übung, sonst (alles erledigt) die letzte, analog zu
    /// `firstIncompleteExerciseName`s Fallback-Logik.
    private var activeRoundIndex: Int? {
        primary.workSets.first(where: { !$0.isCompleted })?.setIndex
            ?? primary.workSets.map(\.setIndex).max()
    }

    private struct Round: Identifiable {
        let primarySet: SetLog
        let attachedSet: SetLog?
        let isActive: Bool
        var id: PersistentIdentifier { primarySet.persistentModelID }
    }

    private var rounds: [Round] {
        let attachedByIndex = Dictionary(uniqueKeysWithValues: attached.workSets.map { ($0.setIndex, $0) })
        let active = activeRoundIndex
        return primary.workSets
            .sorted { $0.setIndex < $1.setIndex }
            .map { primarySet in
                Round(
                    primarySet: primarySet,
                    attachedSet: attachedByIndex[primarySet.setIndex],
                    isActive: primarySet.setIndex == active
                )
            }
    }

    // Drei `.confirmationDialog`s (bzw. `.confirmRemoval`, das intern selbst
    // eine ist) dürfen NICHT auf demselben View-Knoten landen - SwiftUI
    // zeigt dann zuverlässig nur den innersten an, die äußeren feuern nie
    // (beobachtetes Verhalten: Tap tat sichtbar nichts). Deshalb drei
    // verschachtelte Knoten, jeweils einen pro Dialog.
    var body: some View {
        Group {
            Group {
                cardWithAccentBar
                    .confirmRemoval(title: "Satz entfernen?", pendingID: $pendingSetDeletion) { setLog in
                        viewModel.deleteSet(setLog)
                    }
            }
            .confirmationDialog(
                "Supersatz entkoppeln?",
                isPresented: $isPresentingUnlinkConfirmation,
                titleVisibility: .visible
            ) {
                Button("Entkoppeln", role: .destructive) {
                    withAnimation(DSMotion.fast) {
                        viewModel.unlinkSuperset(exerciseName: attached.name)
                    }
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("\(attached.name) läuft danach als eigenständige Übung weiter, alle Sätze bleiben erhalten.")
            }
        }
        .confirmationDialog(
            "Letzten Supersatz-Satz entfernen?",
            isPresented: Binding(
                get: { pendingLastAttachedSetRemoval != nil },
                set: { if !$0 { pendingLastAttachedSetRemoval = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Entfernen", role: .destructive) {
                if let setLog = pendingLastAttachedSetRemoval {
                    withAnimation(DSMotion.fast) {
                        viewModel.deleteSet(setLog)
                        viewModel.unlinkSuperset(exerciseName: attached.name)
                    }
                }
                pendingLastAttachedSetRemoval = nil
            }
            Button("Abbrechen", role: .cancel) { pendingLastAttachedSetRemoval = nil }
        } message: {
            Text("\(attached.name) wird danach wieder eine normale, eigenständige Übung.")
        }
    }

    /// Der Akzent-Balken sitzt als `.overlay` AUF der Karte statt als
    /// eigenständiges Sibling daneben (frühere Version) - nur so lässt er
    /// sich mit `.clipShape` exakt auf dieselbe `RoundedRectangle` wie
    /// `DSCard` selbst zuschneiden, wodurch seine Ecken oben/unten
    /// automatisch der großen Karten-Rundung folgen, statt eckig
    /// abzuschneiden. `DSColor.headerWash` statt einer neuen zweiten
    /// Verlaufsfarbe - siehe deren Doc-Kommentar.
    private var cardWithAccentBar: some View {
        DSCard(
            padding: DSSpacing.s16,
            background: isComplete ? DSColor.accentTrack.opacity(0.4) : DSColor.surfaceCard
        ) {
            VStack(alignment: .leading, spacing: DSSpacing.stackGap) {
                Text("SUPERSATZ")
                    .font(DSFont.label)
                    .foregroundStyle(DSColor.accent)
                    .tracking(1)
                    .accessibilityHidden(true)

                exerciseHeader
                linkInfoRow

                ForEach(rounds) { round in
                    roundView(round)
                }

                addSetRow
            }
        }
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(DSColor.headerWash)
                .frame(width: 3)
        }
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
        .matchedGeometryEffect(id: primary.name, in: namespace)
    }

    private var exerciseHeader: some View {
        HStack {
            Text(primary.name)
                .font(DSFont.body)
                .foregroundStyle(DSColor.textPrimary)
                .matchedGeometryEffect(id: "\(primary.name)-title", in: namespace)
            if isComplete {
                DSIcon(name: "check", size: 16)
                    .foregroundStyle(DSColor.accent)
                    .accessibilityHidden(true)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(isComplete ? "vollständig abgehakt" : "")
    }

    /// Kompakte Zeile statt eines eigenen Headers für die angehängte Übung -
    /// die Runden selbst tragen jetzt den Inhalt, hier steht nur noch, WAS
    /// verknüpft ist, plus Kette als Entkoppeln-Button (mit Bestätigung,
    /// siehe `isPresentingUnlinkConfirmation`).
    private var linkInfoRow: some View {
        HStack(spacing: DSSpacing.s8) {
            Button {
                isPresentingUnlinkConfirmation = true
            } label: {
                chainGlyph(width: 16, height: 9, lineWidth: 1.5)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Supersatz entkoppeln")
            .accessibilityHint("Löst \(attached.name) von \(primary.name)")

            Text("verknüpft mit \(attached.name)")
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)

            Spacer()
        }
    }

    @ViewBuilder
    private func roundView(_ round: Round) -> some View {
        VStack(spacing: DSSpacing.s8) {
            row(round.primarySet, section: primary, style: .solid)

            if let attachedSet = round.attachedSet {
                miniChainConnector
                    .padding(.vertical, -22)
                    .zIndex(-1)
                row(attachedSet, section: attached, style: .dashed)
            } else if round.isActive, let attachedExercise = attached.sets.first?.exercise ?? attached.target?.exercise {
                let lastAttachedSet = attached.workSets.last
                AddSetBarButton(title: "+ Supersatz") {
                    viewModel.addSet(
                        for: attachedExercise,
                        suggestedReps: lastAttachedSet?.reps ?? attached.target?.targetReps,
                        suggestedWeightKg: lastAttachedSet?.weightKg ?? attached.target?.targetWeightKg
                    )
                }
            }
        }
    }

    private func row(_ setLog: SetLog, section: ExerciseSection, style: SetRowStyle) -> some View {
        let nextSetID = viewModel.nextIncompleteSetID(in: section.name)
        // Der letzte verbleibende Satz der ANGEHÄNGTEN Übung ist ein
        // Sonderfall (siehe `pendingLastAttachedSetRemoval`) - alle anderen
        // Sätze (primäre Übung, oder angehängte mit weiteren Runden) laufen
        // über den normalen "Satz entfernen?"-Dialog.
        let isLastAttachedSet = section.name == attached.name && attached.workSets.count == 1
        return SwipeToDeleteRow(onDelete: {
            if isLastAttachedSet {
                pendingLastAttachedSetRemoval = setLog
            } else {
                pendingSetDeletion = setLog
            }
        }) {
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
                isNextUp: setLog.persistentModelID == nextSetID,
                onFieldFocusChange: onFieldFocusChange,
                style: style
            )
        }
    }

    /// "+ Satz" fügt der PRIMÄREN Übung eine weitere Runde hinzu - die
    /// angehängte Übung wächst ausschließlich rundenweise über den
    /// "+ Supersatz"-Button in `roundView`, nie eigenständig.
    private var addSetRow: some View {
        Group {
            if let exercise = primary.sets.first?.exercise ?? primary.target?.exercise {
                let last = primary.workSets.last
                AddSetBarButton(title: "Satz") {
                    viewModel.addSet(
                        for: exercise,
                        suggestedReps: last?.reps ?? primary.target?.targetReps,
                        suggestedWeightKg: last?.weightKg ?? primary.target?.targetWeightKg
                    )
                }
            }
        }
    }

    /// Zwei gedrehte, hohle Kapsel-Ringe statt eines neuen Icon-Assets.
    private func chainGlyph(width: CGFloat, height: CGFloat, lineWidth: CGFloat) -> some View {
        ZStack {
            Capsule()
                .strokeBorder(DSColor.accent, lineWidth: lineWidth)
                .frame(width: width, height: height)
                .rotationEffect(.degrees(90))
                .offset(y: -height / 2.2)
            Capsule()
                .strokeBorder(DSColor.accent, lineWidth: lineWidth)
                .frame(width: width, height: height)
                .rotationEffect(.degrees(90))
                .offset(y: height / 2.2)
        }
    }

    /// Sitzt in der Z-Reihenfolge HINTER der primären und der angehängten
    /// Zeile derselben Runde (`.zIndex(-1)` in `roundView`), nicht in einer
    /// eigenen Divider-Zeile davor. Die stark negative vertikale Padding
    /// lässt sie weit in beide Nachbarn hineinbluten - deren eigene, opake
    /// Hintergründe verdecken sie dort automatisch, sichtbar bleibt nur der
    /// schmale Spalt dazwischen, als liefe die Kette tatsächlich unter
    /// beiden Zeilen durch - verkettet genau DIESES Satz-Paar, nicht mehr
    /// zwei ganze Übungs-Blöcke.
    private var miniChainConnector: some View {
        HStack {
            Spacer()
            chainGlyph(width: 18, height: 10, lineWidth: 1.5)
                .frame(height: 36)
            Spacer()
        }
        .accessibilityHidden(true)
    }
}
