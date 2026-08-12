import Testing
import Foundation
@testable import WorkoutTracker

/// Reine Encode/Decode-Round-Trip-Tests (ADR 0013) - `WidgetSnapshotStore`s
/// tatsächliche App-Group-Container-I/O wird hier bewusst nicht getestet
/// (dünnes FileManager-Passthrough, siehe Journal), nur dass die Snapshot-
/// DTOs verlustfrei durch JSONEncoder/-Decoder round-trippen.
struct WidgetSnapshotWritingTests {
    @Test func nextWorkoutSnapshotRoundTrips() throws {
        let snapshot = NextWorkoutSnapshot(programName: "Arnold Split", dayLabel: "Day 1", workoutName: "Push")

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(NextWorkoutSnapshot.self, from: data)

        #expect(decoded.programName == snapshot.programName)
        #expect(decoded.dayLabel == snapshot.dayLabel)
        #expect(decoded.workoutName == snapshot.workoutName)
    }

    @Test func heatmapSnapshotRoundTrips() throws {
        let days = [
            DayCount(date: Date(timeIntervalSince1970: 0), count: 0),
            DayCount(date: Date(timeIntervalSince1970: 86400), count: 2, moveRingClosed: true),
        ]
        let snapshot = HeatmapSnapshot(days: days)

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(HeatmapSnapshot.self, from: data)

        #expect(decoded.days.map(\.count) == [0, 2])
        #expect(decoded.days.map(\.date) == days.map(\.date))
        #expect(decoded.days.map(\.moveRingClosed) == [false, true])
    }

    /// Rückwärtskompatibilität: ein VOR diesem Feature geschriebener
    /// Widget-Snapshot hat keinen `moveRingClosed`-Key im JSON. Ohne den
    /// Custom-`Decodable`-Init würde das mit `keyNotFound` scheitern statt
    /// auf `false` zu defaulten - das Widget würde dann per `try?` in
    /// `WidgetSnapshotStore.read` ein leeres Grid zeigen statt der zuletzt
    /// bekannten Daten, bis zum nächsten Refresh.
    @Test func dayCountDecodesMissingMoveRingKeyAsFalse() throws {
        let json = Data("""
        {"date": 0, "count": 2}
        """.utf8)

        let decoded = try JSONDecoder().decode(DayCount.self, from: json)

        #expect(decoded.count == 2)
        #expect(decoded.moveRingClosed == false)
    }

    @Test func extendedToTodayFillsMissingDaysWithZero() throws {
        let calendar = Calendar.current
        let twoDaysAgo = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_000_000))
        let today = calendar.date(byAdding: .day, value: 2, to: twoDaysAgo)!
        let days = [DayCount(date: twoDaysAgo, count: 3)]

        let extended = days.extendedToToday(calendar: calendar, today: today)

        #expect(extended.count == 3)
        #expect(extended[0].date == twoDaysAgo)
        #expect(extended[0].count == 3)
        #expect(extended[1].count == 0)
        #expect(extended[2].date == today)
        #expect(extended[2].count == 0)
    }

    @Test func extendedToTodayIsNoOpWhenAlreadyCurrent() throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let days = [DayCount(date: today, count: 1)]

        let extended = days.extendedToToday(calendar: calendar, today: today)

        #expect(extended.count == 1)
        #expect(extended.map(\.date) == days.map(\.date))
        #expect(extended.map(\.count) == days.map(\.count))
    }
}
