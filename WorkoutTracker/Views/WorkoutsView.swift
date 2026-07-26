import SwiftUI

/// Placeholder for the app-init phase. Will later host the workout
/// builder and the session flow (create workout, run session, log sets,
/// rest timer) built out in Phase C.
struct WorkoutsView: View {
    var body: some View {
        DSWashedScreen {
            VStack(alignment: .leading, spacing: DSSpacing.stackGap) {
                Text("Workouts")
                    .font(DSFont.screenTitle)
                    .foregroundStyle(DSColor.textPrimary)

                Text("Coming soon")
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Workouts")
    }
}

#Preview {
    NavigationStack {
        WorkoutsView()
    }
}
