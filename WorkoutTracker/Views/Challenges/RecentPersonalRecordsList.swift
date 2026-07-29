import SwiftUI

/// Zuletzt erzielte Gewichts-Rekorde.
struct RecentPersonalRecordsList: View {
    let records: [PersonalRecord]

    var body: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSSpacing.s8) {
                Text("Letzte Rekorde")
                    .font(DSFont.label)
                    .foregroundStyle(DSColor.textSecondary)
                if records.isEmpty {
                    Text("Noch keine Rekorde")
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textTertiary)
                } else {
                    ForEach(records) { record in
                        HStack {
                            Text(record.exerciseName)
                                .font(DSFont.body)
                                .foregroundStyle(DSColor.textPrimary)
                            Spacer()
                            Text("\(record.weightKg.formatted(.number.precision(.fractionLength(0...1)))) kg")
                                .font(DSFont.caption)
                                .foregroundStyle(DSColor.accent)
                        }
                    }
                }
            }
        }
    }
}
