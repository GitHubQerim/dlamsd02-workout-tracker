import Foundation

enum ActivityType: String, Codable, CaseIterable, Identifiable {
    case kraft
    case radfahren
    case laufen
    case tennis
    case sonstiges

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .kraft: return "Kraft"
        case .radfahren: return "Radfahren"
        case .laufen: return "Laufen"
        case .tennis: return "Tennis"
        case .sonstiges: return "Sonstiges"
        }
    }

    /// Ob diese Sportart Kraft-Sätze (`SetLog`) statt Cardio-Metriken
    /// (Distanz/Dauer/Puls) protokolliert. Nur in Swift-Code auswerten,
    /// nicht in `#Predicate` (computed properties auf Enums werden dort
    /// nicht unterstützt) - dort gegen den Rohwert filtern.
    var usesSetLogs: Bool { self == .kraft }
}
