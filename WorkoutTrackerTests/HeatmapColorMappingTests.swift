import Testing
@testable import WorkoutTracker

struct HeatmapColorMappingTests {
    @Test func emptyDayIsN700() {
        let day = DayCount(date: .now, count: 0)
        #expect(HeatmapColorMapping.color(for: day) == DSColor.n700)
    }

    @Test func singleSessionIsAlreadyFull() {
        // Dokumentiert die Session-Anzahl-Regel (ADR 0015) - anders als
        // früher reicht schon EINE Session für die volle Farbe, nicht erst 3+.
        let day = DayCount(date: .now, count: 1)
        #expect(HeatmapColorMapping.color(for: day) == DSColor.accent)
    }

    @Test func closedMoveRingWithoutSessionIsMediumNotFull() {
        // Nachtrag zu ADR 0015 nach echtem Gerätetest: reine
        // Alltagsbewegung ohne geloggtes Workout bekommt eine mittlere
        // Stufe, keine volle Farbe - sonst nicht mehr unterscheidbar von
        // einem echten Training.
        let day = DayCount(date: .now, count: 0, moveRingClosed: true)
        let color = HeatmapColorMapping.color(for: day)
        #expect(color == DSColor.green700)
        #expect(color != DSColor.accent)
    }

    @Test func sessionAlwaysOutranksMoveRingRegardlessOfRingState() {
        let day = DayCount(date: .now, count: 1, moveRingClosed: true)
        #expect(HeatmapColorMapping.color(for: day) == DSColor.accent)
    }

    @Test func multipleSessionsLookTheSameAsOne() {
        // Dokumentiert den bewusst akzeptierten Informationsverlust (ADR
        // 0015): die frühere 1/2/3+-Nuance zwischen Session-Anzahlen gibt
        // es nicht mehr - nur die Move-Ring-Zwischenstufe ist neu.
        let oneSession = DayCount(date: .now, count: 1)
        let threeSessions = DayCount(date: .now, count: 3)
        #expect(HeatmapColorMapping.color(for: oneSession) == HeatmapColorMapping.color(for: threeSessions))
    }
}
