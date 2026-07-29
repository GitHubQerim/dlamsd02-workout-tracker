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
            DayCount(date: Date(timeIntervalSince1970: 86400), count: 2),
        ]
        let snapshot = HeatmapSnapshot(days: days)

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(HeatmapSnapshot.self, from: data)

        #expect(decoded.days.map(\.count) == [0, 2])
        #expect(decoded.days.map(\.date) == days.map(\.date))
    }
}
