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
                        PersonalRecordRow(record: record)
                    }
                }
            }
        }
    }
}
