import SwiftUI

/// Inline tap-to-edit Zahlenfeld für Reps/Gewicht in `SetRow` - ersetzt den
/// vorherigen `DSWheelPickerField`-Sheet-Ansatz für die LIVE-Satz-Eingabe
/// (Wheel-Picker in WorkoutEditorView/WorkoutSessionView-Segmenten bleiben
/// unverändert, dort gab es keine Kritik). Bewusst kein DS-Component (siehe
/// Doc-Kommentar in SetRow) - Quick-Adjust-Deltas und das "letzte Einheit"-
/// Placeholder-Konzept sind Domänenwissen.
struct SetValueField: View {
    enum Kind: Equatable {
        case reps
        case weightKg

        /// Nudge-Schritte für die Tastatur-Toolbar - für Reps gab es keine
        /// expliziten Nutzer-Vorgaben, gewählt in Analogie zu den genannten
        /// Gewichts-Deltas (kleinerer Grundschritt, gleicher großer Schritt).
        var quickAdjustDeltas: [Double] {
            switch self {
            case .reps: [-1, 1, 5]
            case .weightKg: [-2.5, 2.5, 5]
            }
        }

        var allowsDecimals: Bool { self == .weightKg }
        var keyboardType: UIKeyboardType { allowsDecimals ? .decimalPad : .numberPad }
    }

    let kind: Kind
    /// Aktuell committeter Wert. `0` ist der bestehende "kein Wert"-Sentinel
    /// (siehe SetLog/PlannedExercise) - wird NICHT als "0" angezeigt, sondern
    /// als leeres Feld mit `placeholder` als grauem Vorschlag.
    var value: Double
    /// Letzte-Einheit-Snapshot für Placeholder, nil wenn keine vorherige
    /// Session existiert.
    var placeholder: Double?
    var accessibilityLabel: String
    var onCommit: (Double) -> Void
    /// Meldet Fokus-Gewinn/-Verlust nach außen - die permanente Bottom-Pille
    /// in `WorkoutSessionView` blendet sich damit aus, solange die
    /// Tastatur-Toolbar dieses Feldes sichtbar ist (beide sitzen sonst im
    /// selben Bereich am unteren Bildschirmrand und überlappen sich).
    /// Default `nil` hält bestehende Previews/Aufrufer lauffähig.
    var onFocusChange: ((Bool) -> Void)? = nil

    @FocusState private var isFocused: Bool
    @State private var text: String = ""
    @State private var selection: TextSelection?

    var body: some View {
        TextField("", text: $text, selection: $selection)
            .keyboardType(kind.keyboardType)
            .multilineTextAlignment(.center)
            .font(DSFont.body)
            .focused($isFocused)
            .padding(.horizontal, DSSpacing.s8)
            .frame(minHeight: DSSpacing.tapMin) // 44pt Tap-Target auf der ganzen Zelle
            .background(fieldBackground)
            .overlay(alignment: .center) {
                if text.isEmpty, let placeholder {
                    Text(displayText(placeholder))
                        .font(DSFont.body)
                        .foregroundStyle(DSColor.textTertiary)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .onAppear(perform: syncTextFromValue)
            .onChange(of: value) { _, _ in if !isFocused { syncTextFromValue() } }
            .onChange(of: isFocused) { _, focused in
                if focused {
                    selectAll()
                } else {
                    commit()
                }
                onFocusChange?(focused)
            }
            .toolbar { keyboardToolbar }
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(value == 0 ? (placeholder.map { "kein Wert, Vorschlag \(displayText($0))" } ?? "kein Wert") : displayText(value))
            .accessibilityHint("Tippen zum Bearbeiten")
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: DSRadius.field, style: .continuous)
            .fill(isFocused ? DSColor.accentTrack.opacity(0.6) : DSColor.fieldFill)
            .padding(.vertical, 6) // sichtbare Fläche schmaler als der 44pt Tap-Bereich
    }

    @ToolbarContentBuilder
    private var keyboardToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            if isFocused {
                ForEach(kind.quickAdjustDeltas, id: \.self) { delta in
                    Button(deltaLabel(delta)) { applyQuickAdjust(delta) }
                }
                Spacer()
                Button("Fertig") { isFocused = false }
            }
        }
    }

    private func syncTextFromValue() {
        text = value == 0 ? "" : displayText(value)
    }

    private func selectAll() {
        selection = TextSelection(range: text.startIndex..<text.endIndex)
    }

    private func commit() {
        let parsed = Double(text.replacingOccurrences(of: ",", with: ".")) ?? 0
        onCommit(max(0, parsed))
    }

    private func applyQuickAdjust(_ delta: Double) {
        let base = Double(text.replacingOccurrences(of: ",", with: ".")) ?? (placeholder ?? 0)
        text = displayText(max(0, base + delta))
    }

    private func displayText(_ value: Double) -> String {
        kind.allowsDecimals
            ? value.formatted(.number.precision(.fractionLength(0...1)))
            : "\(Int(value.rounded()))"
    }

    private func deltaLabel(_ delta: Double) -> String {
        let sign = delta >= 0 ? "+" : "−"
        return "\(sign)\(displayText(abs(delta)))"
    }
}
