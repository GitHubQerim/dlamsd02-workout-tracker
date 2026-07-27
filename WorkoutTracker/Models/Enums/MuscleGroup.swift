import Foundation

enum MuscleGroup: String, Codable, CaseIterable, Identifiable {
    case brust, ruecken, beine, schultern, arme, bauch, ganzkoerper

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .brust: return "Brust"
        case .ruecken: return "Rücken"
        case .beine: return "Beine"
        case .schultern: return "Schultern"
        case .arme: return "Arme"
        case .bauch: return "Bauch"
        case .ganzkoerper: return "Ganzkörper"
        }
    }
}
