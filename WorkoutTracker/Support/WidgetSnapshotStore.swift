import Foundation
import OSLog

/// Geteilter App-Group-Speicher für Home-Screen-Widget-Snapshots (ADR 0013) -
/// eine Container-Pfad-Logik statt getrennter App-/Extension-Kopien. Bewusst
/// keine geteilte SwiftData-Instanz (ADR 0001: Multi-Prozess-Zugriff auf
/// denselben Store ist riskant) - nur kleine, zweckgebundene JSON-Snapshots.
enum WidgetSnapshotStore {
    static let appGroupIdentifier = "group.com.qerim.dlamsd02.workouttracker"

    private static let logger = Logger(subsystem: "com.qerim.dlamsd02.workouttracker", category: "WidgetSnapshotStore")

    /// Schreibfehler sind bewusst kein Blocker (Widgets sind ein Zusatzfeature),
    /// aber ein `Logger`-Eintrag statt komplettem Schweigen - sonst ist "warum
    /// aktualisieren sich die Widgets nicht" (z.B. bei falsch konfigurierter
    /// App-Group-Entitlement) nirgends nachvollziehbar.
    static func write<T: Encodable>(_ value: T, filename: String) {
        guard let url = containerURL(for: filename) else {
            logger.error("Kein App-Group-Container für \(filename, privacy: .public) - Entitlement geprüft?")
            return
        }
        guard let data = try? JSONEncoder().encode(value) else {
            logger.error("Snapshot \(filename, privacy: .public) konnte nicht encodiert werden")
            return
        }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            logger.error("Snapshot \(filename, privacy: .public) konnte nicht geschrieben werden: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func delete(filename: String) {
        guard let url = containerURL(for: filename) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    static func read<T: Decodable>(_ type: T.Type, filename: String) -> T? {
        guard let url = containerURL(for: filename), let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private static func containerURL(for filename: String) -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent(filename)
    }
}

struct NextWorkoutSnapshot: Codable {
    static let filename = "next-workout-snapshot.json"
    let programName: String
    let dayLabel: String
    let workoutName: String
}

struct HeatmapSnapshot: Codable {
    static let filename = "heatmap-snapshot.json"
    let days: [DayCount]
}
