import HealthKit

/// Reine Mapping-Funktionen zwischen dem App-eigenen `ActivityType` und
/// HealthKit-Typen - bewusst getrennt von `HealthKitService`, damit sie ohne
/// Mock/HealthKit-Autorisierung unit-testbar sind.
enum HealthKitActivityMapping {
    static func hkActivityType(for activityType: ActivityType) -> HKWorkoutActivityType {
        switch activityType {
        case .kraft: return .traditionalStrengthTraining
        case .radfahren: return .cycling
        case .laufen: return .running
        case .tennis: return .tennis
        case .sonstiges: return .other
        }
    }

    static func activityKind(for hkActivityType: HKWorkoutActivityType) -> HealthKitWorkoutActivityKind {
        switch hkActivityType {
        case .cycling: return .cycling
        case .running: return .running
        case .tennis: return .tennis
        default: return .other
        }
    }

    /// Fallback auf `.sonstiges` bei unbekannten/nicht gemappten HK-Typen
    /// (siehe Phase-E-Scope-Entscheidung) statt den Import zu verwerfen.
    static func activityType(for kind: HealthKitWorkoutActivityKind) -> ActivityType {
        switch kind {
        case .cycling: return .radfahren
        case .running: return .laufen
        case .tennis: return .tennis
        case .other: return .sonstiges
        }
    }
}
