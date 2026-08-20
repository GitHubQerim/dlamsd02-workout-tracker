import SwiftUI

/// Nur manueller Sync (kein Background Delivery/HKObserverQuery, Phase-E-
/// Scope-Entscheidung) - der Nutzer stößt den Import aktiv über den Button an.
struct HealthKitImportView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: HealthKitImportViewModel?

    var body: some View {
        DSWashedScreen {
            VStack(alignment: .leading, spacing: DSSpacing.sectionGap) {
                if let viewModel {
                    if let message = viewModel.errorMessage {
                        Text(message)
                            .font(DSFont.caption)
                            .foregroundStyle(DSColor.incorrect)
                    }

                    if viewModel.importableWorkouts.isEmpty && !viewModel.isRefreshing {
                        DSCard {
                            Text("Keine neuen Cardio-Workouts zum Importieren gefunden.")
                                .font(DSFont.body)
                                .foregroundStyle(DSColor.textSecondary)
                        }
                    }

                    // Kein Bestätigungsdialog: der Import ist nicht destruktiv
                    // und über die normale Session-Löschung rücknehmbar.
                    if !viewModel.importableWorkouts.isEmpty {
                        DSButton(
                            title: "Alle importieren (\(viewModel.importableWorkouts.count))",
                            fullWidth: true
                        ) {
                            viewModel.importAllSessions()
                        }
                        // Während `refresh()` läuft, steht noch die alte Liste
                        // im Screen. Ein Import in diesem Moment würde von der
                        // laufenden Abfrage überschrieben - sie kennt die eben
                        // vergebenen `healthKitUUID`s noch nicht und spielte
                        // die importierten Workouts wieder ein, ein zweiter
                        // Tap legte sie doppelt an.
                        .disabled(viewModel.isRefreshing)
                    }

                    ForEach(viewModel.importableWorkouts) { sample in
                        DSCard {
                            HStack {
                                VStack(alignment: .leading, spacing: DSSpacing.s4) {
                                    Text(HealthKitActivityMapping.activityType(for: sample.hkActivityType).displayName)
                                        .font(DSFont.body)
                                        .foregroundStyle(DSColor.textPrimary)
                                    Text(sample.start.formatted(date: .abbreviated, time: .shortened))
                                        .font(DSFont.caption)
                                        .foregroundStyle(DSColor.textSecondary)
                                }
                                Spacer()
                                DSButton(title: "Importieren", variant: .outline) {
                                    viewModel.importSession(sample)
                                }
                            }
                        }
                    }

                    DSButton(
                        title: viewModel.isRefreshing ? "Synchronisiere…" : "Jetzt synchronisieren",
                        fullWidth: true
                    ) {
                        Task { await viewModel.refresh() }
                    }
                    .disabled(viewModel.isRefreshing)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Health-Import")
        .task {
            if viewModel == nil {
                viewModel = HealthKitImportViewModel(context: modelContext)
            }
        }
    }
}

#Preview {
    NavigationStack {
        HealthKitImportView()
    }
}
