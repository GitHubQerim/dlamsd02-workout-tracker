import Foundation

enum SessionSource: String, Codable, CaseIterable, Identifiable {
    case manual
    case healthKitImport

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .manual: return "Manuell erfasst"
        case .healthKitImport: return "Aus Health importiert"
        }
    }
}
