import SwiftUI

/// Placeholder for the app-init phase. Will later show the current status
/// toward active challenges (Aufgabenstellung 3's mandatory start screen).
struct DashboardView: View {
    var body: some View {
        DSWashedScreen {
            VStack(alignment: .leading, spacing: DSSpacing.stackGap) {
                Text("Dashboard")
                    .font(DSFont.screenTitle)
                    .foregroundStyle(DSColor.textPrimary)

                Text("Coming soon")
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Dashboard")
    }
}

#Preview {
    NavigationStack {
        DashboardView()
    }
}
