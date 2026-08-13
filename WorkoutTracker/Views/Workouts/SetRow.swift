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

/// `.dashed` markiert eine Zeile als "nicht der normale Arbeitssatz" -
/// aktuell für Warm-up-Sätze in `ActiveExerciseCard` (gestrichelt, gedämpft,
/// eigene, unabhängige Nummerierung, siehe `ExerciseSection.warmupSets`) und
/// künftig für die "angehängte" Übung eines Supersatzes wiederverwendet.
/// Bewusst kein neuer Farbwert - nur Fläche/Rahmen ändern sich, damit das
/// Ein-Akzentfarben-Prinzip (`DesignSystem/Colors.swift`) gewahrt bleibt.
enum SetRowStyle {
    case solid
    case dashed
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
    /// Siehe `SetRowStyle`. Default `.solid` hält bestehende Aufrufer/
    /// Previews unverändert.
    var style: SetRowStyle = .solid

    private var badgeSize: CGFloat { style == .dashed ? 24 : SetRowLayout.badge }
    private var toggleSize: CGFloat { style == .dashed ? 28 : SetRowLayout.toggle }

    private var badgeFillColor: Color {
        if setLog.isCompleted { return DSColor.accent }
        return style == .dashed ? .clear : DSColor.surfaceCard2
    }

    private var badgeTextColor: Color {
        if setLog.isCompleted { return DSColor.textOnInvert }
        return style == .dashed ? DSColor.textTertiary : DSColor.textSecondary
    }

    private var valueTextColor: Color {
        if setLog.isCompleted { return DSColor.textSecondary }
        return style == .dashed ? DSColor.textSecondary : DSColor.textPrimary
    }

    private var rowBackground: Color {
        guard style == .solid else { return .clear }
        return setLog.isCompleted ? DSColor.accentTrack.opacity(0.4) : DSColor.surfaceCard2
    }

    var body: some View {
        HStack(spacing: DSSpacing.stackGap) {
            Text("\(setLog.setIndex + 1)")
                .font(DSFont.label)
                .foregroundStyle(badgeTextColor)
                .frame(width: badgeSize, height: badgeSize)
                .background(badgeFillColor)
                .overlay {
                    if style == .dashed && !setLog.isCompleted {
                        Circle().strokeBorder(DSColor.borderStrong, lineWidth: 1.2)
                    }
                }
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
            .foregroundStyle(valueTextColor)
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
                .frame(width: toggleSize, height: toggleSize)
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
        .background(rowBackground)
        .overlay {
            if style == .dashed {
                RoundedRectangle(cornerRadius: DSRadius.tile, style: .continuous)
                    .strokeBorder(DSColor.borderStrong, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.tile, style: .continuous))
        .animation(DSMotion.fast, value: setLog.isCompleted)
    }
}
