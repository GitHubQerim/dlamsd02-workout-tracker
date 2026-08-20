import SwiftUI

/// Neuer, eigenständiger Einstiegspunkt für HealthKit (Phase E) - bewusst
/// kein Onboarding-Zwang beim App-Start, sondern ein dauerhaft auffindbarer
/// Screen, den der Nutzer aufsucht, wenn er die Verbindung herstellen will.
struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()

    var body: some View {
        DSWashedScreen {
            VStack(alignment: .leading, spacing: DSSpacing.sectionGap) {
                DSCard {
                    VStack(alignment: .leading, spacing: DSSpacing.stackGap) {
                        HStack(spacing: DSSpacing.s4) {
                            DSIcon(name: "heart-pulse", size: 16)
                                .foregroundStyle(DSColor.textSecondary)
                            Text("Apple Health")
                                .font(DSFont.label)
                                .foregroundStyle(DSColor.textSecondary)
                        }
                        Text(viewModel.hasRequestedAuthorization ? "Verbunden" : "Nicht verbunden")
                            .font(DSFont.body)
                            .foregroundStyle(DSColor.textPrimary)

                        if let message = viewModel.authorizationErrorMessage {
                            Text(message)
                                .font(DSFont.caption)
                                .foregroundStyle(DSColor.incorrect)
                        }

                        DSButton(
                            title: viewModel.isRequestingAuthorization ? "Verbinde…" : "Mit Apple Health verbinden",
                            variant: .outline,
                            fullWidth: true
                        ) {
                            Task { await viewModel.connectToHealth() }
                        }
                        .disabled(viewModel.isRequestingAuthorization)
                    }
                }

                NavigationLink {
                    HealthKitImportView()
                } label: {
                    DSCard {
                        HStack {
                            Text("Cardio-Workouts aus Health importieren")
                                .font(DSFont.body)
                                .foregroundStyle(DSColor.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(DSColor.textSecondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Einstellungen")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
