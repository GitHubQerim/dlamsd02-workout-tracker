import Foundation

extension TimeInterval {
    /// `mm:ss` unter einer Stunde, sonst `h:mm:ss` - gemeinsamer Formatter
    /// für Gesamt- und Pausen-Timer im Session-Flow.
    var formattedClock: String {
        let totalSeconds = max(0, Int(self.rounded()))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
