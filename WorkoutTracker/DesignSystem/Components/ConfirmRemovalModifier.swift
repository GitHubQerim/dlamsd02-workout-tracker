import SwiftUI

extension View {
    /// Bestätigungs-Dialog vor dem endgültigen Entfernen einer Zeile aus
    /// einer Liste (Übungen, Segmente, Plan-Tage, Sätze) - dieselbe Form an
    /// mehreren Stellen (`WorkoutEditorView`, `WorkoutProgramEditorView`,
    /// `ActiveExerciseCard`), deshalb als eine gemeinsame View-Extension
    /// statt mehrfach dupliziert. `pendingID` wird von `.onDelete` gesetzt
    /// statt die Entfernung direkt auszuführen; erst der "Entfernen"-Button
    /// hier ruft `onConfirm` auf. Generisch über die ID statt fest auf
    /// `UUID` - `SetLog`s Identität ist SwiftDatas `PersistentIdentifier`,
    /// nicht ein eigenes `UUID`-Feld wie bei den Editor-Drafts.
    func confirmRemoval<ID: Hashable>(title: String, pendingID: Binding<ID?>, onConfirm: @escaping (ID) -> Void) -> some View {
        confirmationDialog(
            title,
            isPresented: Binding(
                get: { pendingID.wrappedValue != nil },
                set: { if !$0 { pendingID.wrappedValue = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingID.wrappedValue
        ) { id in
            // `presenting:` reicht die bereits entpackte ID durch - kein
            // `if let` nötig, das sonst einen (aktuell unerreichbaren) toten
            // Else-Zweig hätte, falls `pendingID` sich je zwischen Anzeigen
            // und Bestätigen ändern würde.
            Button("Entfernen", role: .destructive) {
                onConfirm(id)
                pendingID.wrappedValue = nil
            }
            Button("Abbrechen", role: .cancel) { pendingID.wrappedValue = nil }
        }
    }
}
