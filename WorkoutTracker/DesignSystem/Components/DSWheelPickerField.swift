import SwiftUI

/// Tappable row (label + current value) that opens a wheel-style picker
/// sheet on tap - the Apple Health "pick a number" pattern, used instead of
/// a +/- `Stepper` or keyboard `TextField` wherever the value range makes
/// tapping/typing tedious. Kept generic (no reps/weight/duration knowledge)
/// per DesignSystem convention - concrete option lists and formatting live
/// at the call sites. Unlike other DS components this one owns presentation
/// state (`isPresenting`), which is the tradeoff for keeping "tap row ->
/// open wheel -> commit" self-contained instead of scattering `@State`
/// across every call site.
struct DSWheelPickerField<Value: Hashable>: View {
    let label: String
    let value: Value
    let options: [Value]
    let displayText: (Value) -> String
    var accessibilityLabel: String? = nil
    /// Hides the inline label, showing only the current value - for compact
    /// contexts (e.g. `SetRow`) where a surrounding column header already
    /// names the field. The sheet still uses `label` for its title/a11y.
    var showsLabel: Bool = true
    let onCommit: (Value) -> Void

    @State private var isPresenting = false
    @State private var draftValue: Value

    init(
        label: String,
        value: Value,
        options: [Value],
        displayText: @escaping (Value) -> String,
        accessibilityLabel: String? = nil,
        showsLabel: Bool = true,
        onCommit: @escaping (Value) -> Void
    ) {
        self.label = label
        self.value = value
        self.options = options
        self.displayText = displayText
        self.accessibilityLabel = accessibilityLabel
        self.showsLabel = showsLabel
        self.onCommit = onCommit
        _draftValue = State(initialValue: value)
    }

    var body: some View {
        Button {
            draftValue = value
            isPresenting = true
        } label: {
            HStack {
                if showsLabel {
                    Text(label)
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textSecondary)
                    Spacer()
                }
                Text(displayText(value))
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.textPrimary)
            }
            .frame(maxWidth: showsLabel ? .infinity : nil)
            .frame(minHeight: DSSpacing.tapMin)
        }
        .buttonStyle(DSPressable())
        .accessibilityLabel(accessibilityLabel ?? label)
        .accessibilityValue(displayText(value))
        .accessibilityHint("Doppeltippen zum Ändern")
        .sheet(isPresented: $isPresenting) {
            NavigationStack {
                Picker(label, selection: $draftValue) {
                    ForEach(options, id: \.self) { option in
                        Text(displayText(option)).tag(option)
                    }
                }
                .pickerStyle(.wheel)
                .navigationTitle(label)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fertig") {
                            onCommit(draftValue)
                            isPresenting = false
                        }
                    }
                }
            }
            .presentationDetents([.height(280)])
        }
    }
}
