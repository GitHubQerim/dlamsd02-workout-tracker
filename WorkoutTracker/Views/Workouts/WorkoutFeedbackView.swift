import SwiftUI

/// Kurzer Zwischenscreen nach "Speichern & beenden": eine optionale Notiz
/// zur gerade abgeschlossenen Session. Nicht verpflichtend - Wegwischen ohne
/// "Fertig" lässt die Notiz einfach leer/unverändert (siehe onDismiss-Handling
/// in `WorkoutSessionView`).
struct WorkoutFeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: WorkoutSessionViewModel

    @State private var notesDraft: String = ""

    var body: some View {
        NavigationStack {
            DSWashedScreen {
                VStack(alignment: .leading, spacing: DSSpacing.sectionGap) {
                    Text("Training abgeschlossen")
                        .font(DSFont.screenTitle)
                        .foregroundStyle(DSColor.textPrimary)

                    DSCard {
                        VStack(alignment: .leading, spacing: DSSpacing.s8) {
                            Text("Notiz")
                                .font(DSFont.label)
                                .foregroundStyle(DSColor.textSecondary)
                            TextField("Wie lief's? (optional)", text: $notesDraft, axis: .vertical)
                                .font(DSFont.body)
                                .foregroundStyle(DSColor.textPrimary)
                                .lineLimit(4...8)
                        }
                    }

                    DSButton(title: "Fertig", fullWidth: true) {
                        viewModel.updateNotes(notesDraft)
                        dismiss()
                    }
                }
            }
            .onAppear { notesDraft = viewModel.session.notes ?? "" }
        }
    }
}
