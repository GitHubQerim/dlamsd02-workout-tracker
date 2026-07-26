import SwiftUI

/// Placeholder for the app-init phase. Will later host the challenge
/// catalog, enrollment and per-challenge progress log (Phase D).
struct ChallengesView: View {
    var body: some View {
        DSWashedScreen {
            VStack(alignment: .leading, spacing: DSSpacing.stackGap) {
                Text("Challenges")
                    .font(DSFont.screenTitle)
                    .foregroundStyle(DSColor.textPrimary)

                Text("Coming soon")
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Challenges")
    }
}

#Preview {
    NavigationStack {
        ChallengesView()
    }
}
