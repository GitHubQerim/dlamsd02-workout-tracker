import SwiftUI
import SwiftData

/// Eindeutiges Feld für die geteilte Tastatur-Toolbar in `WorkoutSessionView`
/// (ein `@FocusState` pro Bildschirm statt pro Zeile - sonst würden mehrere
/// gleichzeitig existierende `SetRow`s in der Liste jeweils eigene
/// `.toolbar(.keyboard)`-Inhalte registrieren).
enum SetRowField: Hashable {
    case reps(PersistentIdentifier)
    case weight(PersistentIdentifier)
}

/// Eine Satz-Zeile in der aktiven Übungskarte: Set-Nummer-Badge (bleibt beim
/// Abhaken unverändert sichtbar), direkt antippbare Reps-/Gewicht-Felder
/// (kein Stepper - das war der explizite Auslöser des Nutzer-Feedbacks: kleine
/// +/- Buttons sind während eines laufenden Workouts umständlich) und ein
/// großer Checkmark-Toggle. Bewusst KEIN `.accessibilityElement(children:
/// .combine)` auf die ganze Zeile - das hätte Button und Felder zu einem
/// einzigen, nicht bedienbaren VoiceOver-Element verschmolzen (siehe
/// docs/journal.md, bereits einmal als echte Regression gefunden).
struct SetRow: View {
    let setLog: SetLog
    let onUpdate: (_ reps: Int, _ weightKg: Double) -> Void
    let onToggle: () -> Void
    var focusedField: FocusState<SetRowField?>.Binding

    var body: some View {
        HStack(spacing: DSSpacing.stackGap) {
            Text("\(setLog.setIndex + 1)")
                .font(DSFont.label)
                .foregroundStyle(setLog.isCompleted ? DSColor.textOnInvert : DSColor.textSecondary)
                .frame(width: 28, height: 28)
                .background(setLog.isCompleted ? DSColor.accent : DSColor.surfaceCard2)
                .clipShape(Circle())
                .accessibilityHidden(true)

            HStack(spacing: DSSpacing.s8) {
                TextField("Wdh.", value: Binding(
                    get: { setLog.reps },
                    set: { onUpdate($0, setLog.weightKg) }
                ), format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .frame(minWidth: 36)
                .focused(focusedField, equals: .reps(setLog.persistentModelID))
                .accessibilityLabel("Wiederholungen, Satz \(setLog.setIndex + 1)")

                Text("×")
                    .foregroundStyle(DSColor.textTertiary)
                    .accessibilityHidden(true)

                TextField("kg", value: Binding(
                    get: { setLog.weightKg },
                    set: { onUpdate(setLog.reps, $0) }
                ), format: .number.precision(.fractionLength(0...1)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .frame(minWidth: 48)
                .focused(focusedField, equals: .weight(setLog.persistentModelID))
                .accessibilityLabel("Gewicht in Kilogramm, Satz \(setLog.setIndex + 1)")

                Text("kg")
                    .foregroundStyle(DSColor.textTertiary)
                    .accessibilityHidden(true)
            }
            .font(DSFont.body)
            .foregroundStyle(setLog.isCompleted ? DSColor.textSecondary : DSColor.textPrimary)

            Spacer(minLength: 0)

            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .strokeBorder(setLog.isCompleted ? .clear : DSColor.borderStrong, lineWidth: 1.5)
                        .background(Circle().fill(setLog.isCompleted ? DSColor.accent : .clear))
                    if setLog.isCompleted {
                        DSIcon(name: "check", size: 18)
                            .foregroundStyle(DSColor.textOnInvert)
                    }
                }
                .frame(width: 36, height: 36)
                .frame(minWidth: DSSpacing.tapMin, minHeight: DSSpacing.tapMin)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.success, trigger: setLog.isCompleted)
            .accessibilityLabel("Satz \(setLog.setIndex + 1) abhaken")
            .accessibilityValue(setLog.isCompleted ? "erledigt" : "offen")
            .accessibilityHint("Doppeltippen zum Abhaken")
            .accessibilityAddTraits(setLog.isCompleted ? [.isSelected] : [])
        }
        .padding(.horizontal, DSSpacing.s12)
        .padding(.vertical, DSSpacing.s12)
        .background(setLog.isCompleted ? DSColor.accentTrack.opacity(0.4) : DSColor.surfaceCard2)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.tile, style: .continuous))
        .animation(DSMotion.fast, value: setLog.isCompleted)
    }
}
