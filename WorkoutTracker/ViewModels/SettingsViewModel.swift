import Foundation

/// Hält den UI-Status der HealthKit-Verbindung. Der tatsächliche
/// Autorisierungsstatus lebt in Apple Health selbst - `hasRequestedAuthorization`
/// wird deshalb bei jeder Instanziierung aus `healthKitService.isAuthorized()`
/// initialisiert, statt naiv bei `false` zu starten. Sonst zeigt der Screen
/// nach jedem App-Neustart fälschlich "Nicht verbunden", obwohl die
/// Berechtigung beim Betriebssystem längst erteilt ist.
@Observable
@MainActor
final class SettingsViewModel {
    private let healthKitService: HealthKitServicing

    private(set) var isRequestingAuthorization = false
    private(set) var hasRequestedAuthorization: Bool
    var authorizationErrorMessage: String?

    init(healthKitService: HealthKitServicing = HealthKitService()) {
        self.healthKitService = healthKitService
        self.hasRequestedAuthorization = healthKitService.isAuthorized()
    }

    func connectToHealth() async {
        isRequestingAuthorization = true
        authorizationErrorMessage = nil
        defer { isRequestingAuthorization = false }
        do {
            try await healthKitService.requestAuthorization()
            hasRequestedAuthorization = healthKitService.isAuthorized()
        } catch {
            authorizationErrorMessage = "Verbindung zu Apple Health fehlgeschlagen: \(error.localizedDescription)"
        }
    }
}
