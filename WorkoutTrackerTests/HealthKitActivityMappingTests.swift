import Testing
import HealthKit
@testable import WorkoutTracker

struct HealthKitActivityMappingTests {
    @Test func hkActivityTypeMapsEachActivityType() {
        #expect(HealthKitActivityMapping.hkActivityType(for: .kraft) == .traditionalStrengthTraining)
        #expect(HealthKitActivityMapping.hkActivityType(for: .radfahren) == .cycling)
        #expect(HealthKitActivityMapping.hkActivityType(for: .laufen) == .running)
        #expect(HealthKitActivityMapping.hkActivityType(for: .tennis) == .tennis)
        #expect(HealthKitActivityMapping.hkActivityType(for: .sonstiges) == .other)
    }

    @Test func activityKindMapsKnownHKTypes() {
        #expect(HealthKitActivityMapping.activityKind(for: .cycling) == .cycling)
        #expect(HealthKitActivityMapping.activityKind(for: .running) == .running)
        #expect(HealthKitActivityMapping.activityKind(for: .tennis) == .tennis)
    }

    @Test func activityKindFallsBackToOtherForUnknownHKTypes() {
        #expect(HealthKitActivityMapping.activityKind(for: .swimming) == .other)
        #expect(HealthKitActivityMapping.activityKind(for: .yoga) == .other)
        #expect(HealthKitActivityMapping.activityKind(for: .traditionalStrengthTraining) == .other)
    }

    @Test func activityTypeMapsEachKind() {
        #expect(HealthKitActivityMapping.activityType(for: .cycling) == .radfahren)
        #expect(HealthKitActivityMapping.activityType(for: .running) == .laufen)
        #expect(HealthKitActivityMapping.activityType(for: .tennis) == .tennis)
        #expect(HealthKitActivityMapping.activityType(for: .other) == .sonstiges)
    }
}
