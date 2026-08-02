import SwiftData

/// Leichte, `Hashable`-Wrapper um `PersistentIdentifier` für `NavigationLink(value:)`.
///
/// Ein `Workout`/`WorkoutProgram`-Objekt direkt als Navigations-Value zu
/// pushen, ließ SwiftUIs AttributeGraph beim Vergleich des kompletten
/// @Model-Objektgraphen (inkl. Relationships) nie zu einem stabilen Ergebnis
/// kommen - jeder Render-Versuch hielt den Wert für "geändert" und löste
/// sofort den nächsten aus (100% CPU, App hängt beim Öffnen eines Workouts).
/// `PersistentIdentifier` ist klein und vergleichsstabil; das Ziel löst das
/// eigentliche Objekt über `ModelContext.registeredModel(for:)` wieder auf.
struct WorkoutNavigationID: Hashable {
    let id: PersistentIdentifier
}

struct WorkoutProgramNavigationID: Hashable {
    let id: PersistentIdentifier
}
