import SwiftUI

/// Zeile für eine noch nicht beigetretene Challenge aus dem festen Katalog.
struct ChallengeCatalogRow: View {
    let challenge: Challenge
    let onJoin: () -> Void

    var body: some View {
        DSCard {
            HStack {
                VStack(alignment: .leading, spacing: DSSpacing.s4) {
                    Text(challenge.name)
                        .font(DSFont.body)
                        .foregroundStyle(DSColor.textPrimary)
                    Text(challenge.challengeType.displayName)
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textSecondary)
                }
                Spacer()
                DSButton(title: "Beitreten", variant: .outline, action: onJoin)
            }
        }
    }
}
