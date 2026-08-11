import Testing
@testable import WorkoutTracker

struct EnergyEstimatorTests {
    @Test func returnsNilForNonPositiveVolume() {
        #expect(EnergyEstimator.estimatedActiveEnergyKcal(totalVolumeKg: 0, bodyWeightKg: 80, duration: 3600) == nil)
        #expect(EnergyEstimator.estimatedActiveEnergyKcal(totalVolumeKg: -10, bodyWeightKg: 80, duration: 3600) == nil)
    }

    @Test func returnsNilForNonPositiveBodyWeight() {
        #expect(EnergyEstimator.estimatedActiveEnergyKcal(totalVolumeKg: 1000, bodyWeightKg: 0, duration: 3600) == nil)
    }

    @Test func returnsNilForNonPositiveDuration() {
        #expect(EnergyEstimator.estimatedActiveEnergyKcal(totalVolumeKg: 1000, bodyWeightKg: 80, duration: 0) == nil)
    }

    @Test func lightIntensityUsesLowestMET() {
        // relativeIntensity = (200kg / 60min) / 80kg ≈ 0.042 -> unter 0.8-Schwelle
        let kcal = EnergyEstimator.estimatedActiveEnergyKcal(totalVolumeKg: 200, bodyWeightKg: 80, duration: 3600)
        let expected = 3.5 * 80 * 1.0
        #expect(kcal != nil)
        #expect(abs(kcal! - expected) < 0.001)
    }

    @Test func moderateIntensityUsesMidMET() {
        // relativeIntensity = (4500kg / 60min) / 80kg ≈ 0.938 -> zwischen 0.8 und 1.5
        let kcal = EnergyEstimator.estimatedActiveEnergyKcal(totalVolumeKg: 4500, bodyWeightKg: 80, duration: 3600)
        let expected = 5.0 * 80 * 1.0
        #expect(kcal != nil)
        #expect(abs(kcal! - expected) < 0.001)
    }

    @Test func vigorousIntensityUsesHighestMET() {
        // relativeIntensity = (5000kg / 30min) / 80kg ≈ 2.08 -> über 1.5-Schwelle
        let kcal = EnergyEstimator.estimatedActiveEnergyKcal(totalVolumeKg: 5000, bodyWeightKg: 80, duration: 1800)
        let expected = 6.0 * 80 * 0.5
        #expect(kcal != nil)
        #expect(abs(kcal! - expected) < 0.001)
    }

    @Test func exactlyAtModerateThresholdStillUsesLightMET() {
        // relativeIntensity = (3840kg / 60min) / 80kg == 0.8 genau -> Vergleich
        // ist bewusst `>`, nicht `>=` (siehe EnergyEstimator), also noch light.
        let kcal = EnergyEstimator.estimatedActiveEnergyKcal(totalVolumeKg: 3840, bodyWeightKg: 80, duration: 3600)
        let expected = 3.5 * 80 * 1.0
        #expect(kcal != nil)
        #expect(abs(kcal! - expected) < 0.001)
    }

    @Test func exactlyAtVigorousThresholdStillUsesModerateMET() {
        // relativeIntensity = (7200kg / 60min) / 80kg == 1.5 genau -> noch
        // moderate, nicht vigorous (Vergleich ist `>`, nicht `>=`).
        let kcal = EnergyEstimator.estimatedActiveEnergyKcal(totalVolumeKg: 7200, bodyWeightKg: 80, duration: 3600)
        let expected = 5.0 * 80 * 1.0
        #expect(kcal != nil)
        #expect(abs(kcal! - expected) < 0.001)
    }

    @Test func capsImplausiblyLongDurationInsteadOfInflatingKcal() {
        // App 8h im Hintergrund gelassen, bevor "Beenden" getippt wurde -
        // die Dauer darf nicht 1:1 in die Formel einfließen (siehe
        // maxPlausibleDuration).
        let cappedKcal = EnergyEstimator.estimatedActiveEnergyKcal(totalVolumeKg: 500, bodyWeightKg: 80, duration: 8 * 3600)
        let uncappedEquivalent = EnergyEstimator.estimatedActiveEnergyKcal(totalVolumeKg: 500, bodyWeightKg: 80, duration: 3 * 3600)
        #expect(cappedKcal != nil)
        #expect(cappedKcal == uncappedEquivalent)
    }
}
