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

    /// Ob diese Sportart Kraft-Sätze (`SetLog`) statt Cardio-Segmenten
    /// (`SegmentLog`) protokolliert. Nur in Swift-Code auswerten,
    /// nicht in `#Predicate` (computed properties auf Enums werden dort
    /// nicht unterstützt) - dort gegen den Rohwert filtern.
    var usesSetLogs: Bool { self == .kraft }

    struct CardioFieldOptions {
        let showsDistance: Bool
        let showsDuration: Bool
    }

    /// Welche Zielfelder pro Sportart bei einem Cardio-Segment sinnvoll
    /// sind - z.B. hat Tennis keine sinnvolle Distanz-Metrik. `nil` bei
    /// `.kraft` (nutzt stattdessen Sätze/Wdh., siehe `usesSetLogs`).
    var cardioFieldOptions: CardioFieldOptions? {
        switch self {
        case .kraft: return nil
        case .radfahren, .laufen: return CardioFieldOptions(showsDistance: true, showsDuration: true)
        case .tennis: return CardioFieldOptions(showsDistance: false, showsDuration: true)
        case .sonstiges: return CardioFieldOptions(showsDistance: true, showsDuration: true)
        }
    }
}
