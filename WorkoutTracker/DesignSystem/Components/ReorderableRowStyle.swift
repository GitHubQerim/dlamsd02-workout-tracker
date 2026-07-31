import SwiftUI

extension View {
    /// Einheitlicher abgerundeter DSCard-Look für Zeilen in umsortierbaren
    /// Editor-Listen (Plan-Tage, Workout-Übungen/-Segmente) - ersetzt die
    /// eckige Standard-`List`-Zeile. Genutzt an mehreren Stellen
    /// (`WorkoutProgramEditorView`, `WorkoutEditorView`), deshalb als eine
    /// gemeinsame Extension statt mehrfach dupliziert.
    func reorderableRowStyle() -> some View {
        padding(DSSpacing.s12)
            .background(DSColor.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.tile, style: .continuous))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: DSSpacing.s4, leading: 0, bottom: DSSpacing.s4, trailing: 0))
    }
}

/// Rein visueller Hinweis, dass eine Zeile per Long-Press gezogen werden
/// kann - `.onMove` reagiert bereits auf die ganze Zeile ohne Edit-Modus,
/// dieses Icon trägt keine eigene Gesten-Logik.
struct DragHandleIcon: View {
    var body: some View {
        Image(systemName: "line.3.horizontal")
            .foregroundStyle(DSColor.textTertiary)
    }
}
