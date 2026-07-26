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
            }
            .tabItem {
                Label("Workouts", systemImage: "dumbbell.fill")
            }
        }
        .tint(DSColor.accent)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
