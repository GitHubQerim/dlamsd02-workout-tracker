import Testing
@testable import WorkoutTracker

@MainActor
struct SettingsViewModelTests {
    @Test func initReflectsAlreadyGrantedAuthorization() {
        let mock = MockHealthKitService()
        mock.isAuthorizedOverride = true

        let viewModel = SettingsViewModel(healthKitService: mock)

        #expect(viewModel.hasRequestedAuthorization == true)
    }

    @Test func initReflectsMissingAuthorizationWithoutRequestingIt() {
        let mock = MockHealthKitService()
        mock.isAuthorizedOverride = false

        let viewModel = SettingsViewModel(healthKitService: mock)

        #expect(viewModel.hasRequestedAuthorization == false)
        #expect(mock.requestAuthorizationCallCount == 0)
    }

    @Test func connectToHealthReflectsGrantedAuthorizationAfterRequest() async {
        let mock = MockHealthKitService()
        let viewModel = SettingsViewModel(healthKitService: mock)
        mock.isAuthorizedOverride = true

        await viewModel.connectToHealth()

        #expect(viewModel.hasRequestedAuthorization == true)
        #expect(viewModel.authorizationErrorMessage == nil)
    }

    @Test func connectToHealthSurfacesErrorAndStaysDisconnected() async {
        let mock = MockHealthKitService()
        mock.authorizationError = HealthKitServiceError.healthDataUnavailable
        let viewModel = SettingsViewModel(healthKitService: mock)

        await viewModel.connectToHealth()

        #expect(viewModel.hasRequestedAuthorization == false)
        #expect(viewModel.authorizationErrorMessage != nil)
    }
}
