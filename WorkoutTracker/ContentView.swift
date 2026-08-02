import SwiftData
import SwiftUI

/// Root navigation: three equally-ranked areas (Dashboard/Challenges/Workouts),
/// unlike DLAMSD01's linear phase-switch — this app has no single linear flow,
/// so a `TabView` with its own `NavigationStack` per tab is the natural fit.
/// The tab bar itself is left to the system (Liquid Glass); screen content
/// stays fully on the GreenDarkFitness design system.
struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack {
                DashboardView()
            }
            .tabItem {
                Label("Dashboard", systemImage: "house.fill")
            }

            NavigationStack {
                ChallengesView()
            }
            .tabItem {
                Label("Challenges", systemImage: "flame.fill")
            }

            NavigationStack {
                WorkoutsView()
                    // Value-based statt eager `NavigationLink { Destination() }`,
                    // aber bewusst mit einer schlanken ID statt dem @Model-
                    // Objekt selbst: `Workout`/`WorkoutProgram` direkt als
                    // Navigations-Value ließ AttributeGraph beim Vergleich
                    // des vollen Objektgraphen (Relationships!) nie zu einem
                    // stabilen Ergebnis kommen - jeder Render-Versuch hielt
                    // den Wert für "geändert" und löste sofort den nächsten
                    // aus (100% CPU, App hängt beim Öffnen eines Workouts).
                    // Registriert hier statt an jeder einzelnen Stelle, damit
                    // sowohl WorkoutsView als auch WorkoutProgramDetailView
                    // (das ebenfalls zu `Workout` navigiert) sie nutzen können.
                    .navigationDestination(for: WorkoutNavigationID.self) { navID in
                        WorkoutDetailResolvingView(id: navID.id)
                    }
                    .navigationDestination(for: WorkoutProgramNavigationID.self) { navID in
                        WorkoutProgramDetailResolvingView(id: navID.id)
                    }
            }
            .tabItem {
                Label("Workouts", systemImage: "dumbbell.fill")
            }
        }
        .tint(DSColor.accent)
        .preferredColorScheme(.dark)
    }
}

/// Löst eine `WorkoutNavigationID` erst innerhalb des Navigationsziels zum
/// tatsächlichen `Workout` auf (siehe Kommentar oben) - der Aufrufer pusht
/// nur die leichte ID, nie das @Model-Objekt selbst.
private struct WorkoutDetailResolvingView: View {
    @Environment(\.modelContext) private var modelContext
    let id: PersistentIdentifier

    var body: some View {
        if let workout: Workout = modelContext.registeredModel(for: id) {
            WorkoutDetailView(plan: workout)
        } else {
            missingView
        }
    }

    private var missingView: some View {
        DSWashedScreen {
            Text("Workout wurde gelöscht")
                .font(DSFont.body)
                .foregroundStyle(DSColor.textSecondary)
        }
        .navigationTitle("Workout")
    }
}

private struct WorkoutProgramDetailResolvingView: View {
    @Environment(\.modelContext) private var modelContext
    let id: PersistentIdentifier

    var body: some View {
        if let program: WorkoutProgram = modelContext.registeredModel(for: id) {
            WorkoutProgramDetailView(program: program)
        } else {
            missingView
        }
    }

    private var missingView: some View {
        DSWashedScreen {
            Text("Plan wurde gelöscht")
                .font(DSFont.body)
                .foregroundStyle(DSColor.textSecondary)
        }
        .navigationTitle("Plan")
    }
}

#Preview {
    ContentView()
}
