import SwiftUI

/// Metric tile adapted from `components/core/StatTile.jsx`, trimmed to the
/// fields the result screen needs (label + icon + value) — the source
/// component's delta/goal-progress affordances don't apply to a quiz result.
struct DSStatTile: View {
    let label: String
    let icon: String
    let value: String
    var valueColor: Color = DSColor.textPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.s8) {
            HStack(spacing: 5) {
                DSIcon(name: icon, size: 13)
                    .foregroundColor(DSColor.textSecondary)
                Text(label)
                    .font(DSFont.caption)
                    .foregroundColor(DSColor.textSecondary)
            }
            Text(value)
                .font(DSFont.metric)
                .foregroundColor(valueColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(EdgeInsets(top: 10, leading: 12, bottom: 11, trailing: 12))
        .background(DSColor.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.tile, style: .continuous))
    }
}
