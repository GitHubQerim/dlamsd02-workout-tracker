import SwiftUI

/// Geteilte Spaltenbreiten zwischen `SetRow` und dem Spalten-Header in
/// `ActiveExerciseCard` - eine Quelle der Wahrheit, damit Header und Zeilen
/// nicht auseinanderlaufen.
enum SetRowLayout {
    static let badge: CGFloat = 28
    static let repsMin: CGFloat = 36
    static let weightMin: CGFloat = 48
    static let toggle: CGFloat = 36
}

/// Eine Satz-Zeile in der aktiven Übungskarte: Set-Nummer-Badge (bleibt beim
/// Abhaken unverändert sichtbar), Reps-/Gewicht-Felder die als inline
/// tap-to-edit-Zahlenfelder mit Quick-Adjust-Tastatur-Toolbar funktionieren
/// (siehe SetValueField - abgelöst den vorherigen Wheel-Picker-Sheet-Ansatz)
/// und ein großer Checkmark-Toggle. Bewusst KEIN
/// `.accessibilityElement(children: .combine)` auf die ganze Zeile - das
/// hätte Button und Felder zu einem einzigen, nicht bedienbaren
/// VoiceOver-Element verschmolzen (siehe docs/journal.md, bereits einmal als
/// echte Regression gefunden).
struct SetRow: View {
    let setLog: SetLog
    let onUpdate: (_ reps: Int, _ weightKg: Double) -> Void
    let onToggle: () -> Void
    /// Markiert den nächsten offenen Satz einer Übung, damit der Blick beim
    /// Weiterarbeiten nicht die ganze Liste absuchen muss. Default `false`
    /// hält bestehende Aufrufer/Previews unverändert lauffähig.
    var isNextUp: Bool = false
    /// Snapshot des gleichnamigen Satzes aus der letzten abgeschlossenen
    /// Session - Placeholder-Quelle für leere Felder. Default `nil` hält
    /// bestehende Previews/Aufrufer lauffähig.
    var previousSet: PreviousSetSnapshot? = nil
    /// Durchgereicht an beide `SetValueField`s, siehe deren Doc-Kommentar.
    var onFieldFocusChange: ((Bool) -> Void)? = nil
    /// Bool-Trigger (nicht Zustand) für den Pausen-Ende-Puls, siehe
    /// `WorkoutSessionView.restExpiredPulseTrigger` - jede `SetRow` bekommt
    /// denselben Wert durchgereicht, reagiert aber nur, wenn sie zusätzlich
    /// `isNextUp` ist (siehe `effectivePulseTrigger`). Default `false` hält
    /// bestehende Previews/Aufrufer lauffähig.
    var pulseTrigger: Bool = false

    /// Nur die aktuell "als nächstes dran"-Zeile pulsiert - andere Zeilen
    /// bekommen einen konstant `false` bleibenden Wert, wodurch
    /// `.animation(value:)` für sie nie anspringt.
    private var effectivePulseTrigger: Bool { isNextUp ? pulseTrigger : false }

    var body: some View {
        HStack(spacing: DSSpacing.stackGap) {
            Text("\(setLog.setIndex + 1)")
                .font(DSFont.label)
                .foregroundStyle(setLog.isCompleted ? DSColor.textOnInvert : DSColor.textSecondary)
                .frame(width: SetRowLayout.badge, height: SetRowLayout.badge)
                .background(setLog.isCompleted ? DSColor.accent : DSColor.surfaceCard2)
                .clipShape(Circle())
                .accessibilityHidden(true)

            HStack(spacing: DSSpacing.s8) {
                SetValueField(
                    kind: .reps,
                    value: Double(setLog.reps),
                    placeholder: previousSet.map { Double($0.reps) },
                    accessibilityLabel: "Wiederholungen, Satz \(setLog.setIndex + 1)",
                    onCommit: { onUpdate(Int($0.rounded()), setLog.weightKg) },
                    onFocusChange: onFieldFocusChange
                )
                .frame(minWidth: SetRowLayout.repsMin)

                Text("×")
                    .foregroundStyle(DSColor.textTertiary)
                    .accessibilityHidden(true)

                SetValueField(
                    kind: .weightKg,
                    value: setLog.weightKg,
                    placeholder: previousSet?.weightKg,
                    accessibilityLabel: "Gewicht in Kilogramm, Satz \(setLog.setIndex + 1)",
                    onCommit: { onUpdate(setLog.reps, $0) },
                    onFocusChange: onFieldFocusChange
                )
                .frame(minWidth: SetRowLayout.weightMin)
            }
            .font(DSFont.body)
            .foregroundStyle(setLog.isCompleted ? DSColor.textSecondary : DSColor.textPrimary)
            .frame(maxWidth: .infinity, alignment: .center)

            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .strokeBorder(setLog.isCompleted ? .clear : DSColor.borderStrong, lineWidth: 1.5)
                        .background(Circle().fill(setLog.isCompleted ? DSColor.accent : .clear))
                    if isNextUp && !setLog.isCompleted {
                        Circle().stroke(DSColor.accent, lineWidth: 2)
                    }
                    if setLog.isCompleted {
                        DSIcon(name: "check", size: 18)
                            .foregroundStyle(DSColor.textOnInvert)
                    }
                }
                .frame(width: SetRowLayout.toggle, height: SetRowLayout.toggle)
                .frame(minWidth: DSSpacing.tapMin, minHeight: DSSpacing.tapMin)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.success, trigger: setLog.isCompleted)
            .accessibilityLabel(
                isNextUp && !setLog.isCompleted
                    ? "Nächster Satz, Satz \(setLog.setIndex + 1) abhaken"
                    : "Satz \(setLog.setIndex + 1) abhaken"
            )
            .accessibilityValue(setLog.isCompleted ? "erledigt" : "offen")
            .accessibilityHint("Doppeltippen zum Abhaken")
            .accessibilityAddTraits(setLog.isCompleted ? [.isSelected] : [])
        }
        .padding(.horizontal, DSSpacing.s12)
        .padding(.vertical, DSSpacing.s12)
        .background(setLog.isCompleted ? DSColor.accentTrack.opacity(0.4) : DSColor.surfaceCard2)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.tile, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.tile, style: .continuous)
                .stroke(DSColor.accent, lineWidth: 1.5)
                .opacity(effectivePulseTrigger ? 0.55 : 0)
        )
        .animation(DSMotion.fast, value: setLog.isCompleted)
        .animation(DSMotion.pulse, value: effectivePulseTrigger)
    }
}
