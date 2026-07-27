# Journal

## 2026-07-26 – Kickoff & Initialisierung

Aufgabenstellung DLAMSD02 gelesen (drei Optionen: Self-Assessment, Merkliste, Tracking-App). Gewählt: Aufgabenstellung 3 (Tracking-App), Themenbereich Multi-Sport-Workout-Tracking – auch mit dem Ziel, die App real im eigenen Training zu nutzen.

Vor der Umsetzung wurden die Grundsatzentscheidungen von einem `architecture-reviewer`-Agenten geprüft. Wichtigste Korrekturen gegenüber der ursprünglichen Idee:
- Challenge-Fortschritt darf nicht rein berechnet werden, sondern muss als `ChallengeProgressEntry` materialisiert (persistiert) werden – sonst ist die Mindestanforderung "Protokollieren erzielter Leistungen in einer Challenge" im Bericht schwer zu belegen (ADR 0002).
- Der Session-Timer muss wall-clock-basiert sein (`startDate` + `elapsed = now - startDate`), nicht als hochzählender Counter – wegen App-Hintergrund/Suspend-Verhalten und als Vorarbeit für eine spätere Live Activity (ADR 0003).
- `WorkoutSession` bekommt von Anfang an ein explizites `id: UUID` sowie ein optionales `healthKitUUID: UUID?`, um HealthKit-Sync später ohne Migration nachzurüsten.

Weitere Entscheidungen für diese Iteration: iOS 26 als Deployment-Target statt 17 (aktuelles SDK, Swift-6-Concurrency, stabileres SwiftData), Multi-Sport-Datenmodell (ein `WorkoutSession`-Typ mit `ActivityType` + optionalen Metrik-Blöcken statt paralleler Entity-Hierarchien pro Sportart), HealthKit von reinem Stretch auf bidirektional hochgezogen (Kraft schreiben, Cardio importieren, inkl. geplanter Dedup-Logik über ein `source`-Feld). Alle sechs Entscheidungen als ADRs unter `docs/adr/` dokumentiert.

**Projekt-Setup:**
- Neues, separates Repo `dlamsd02-workout-tracker` (kein Sub-Ordner von DLAMSD01, da dieses bereits abgegeben ist).
- `project.yml` (XcodeGen) nach dem Muster von DLAMSD01, aber `deploymentTarget.iOS: "26.0"` (statt 16.0) und `SWIFT_VERSION: 6.0` (statt 5.0), Bundle-ID-Namespace `com.qerim.dlamsd02.workouttracker`.
- Design-System "GreenDarkFitness" (7 Token-Files + 7 Components) 1:1 aus `dlamsd01-fitness-quiz` kopiert. Erwartet hatten wir Sendable-/@MainActor-Warnings unter Swift 6 Strict Concurrency – tatsächlich baute das Projekt beim ersten Versuch komplett ohne Warnings durch (SwiftUI-Views sind unter Swift 6 implizit `@MainActor`-isoliert, und die Token-Enums enthalten nur bereits `Sendable`-konforme Werte-Typen wie `Color`/`Font`/`CGFloat`). Kein Anpassungsbedarf – dennoch bewusst geprüft, nicht nur angenommen.
- Manrope-Variable.ttf, AccentColor (#2FB19B) und die 9 vorhandenen Icons (dumbbell, flame, chart-column, check, house, info, heart-pulse, brain, rotate-ccw) übernommen – passen inhaltlich fast alle direkt zum Workout-Tracking-Thema. App-Icon vorerst als Platzhalter vom Vorgänger übernommen (flaches PNG); vollständige, geschichtete Icon-Composer-Version ist für die Finalisierung vorgemerkt.
- Grundgerüst: `TabView` mit drei gleichrangigen Bereichen (Dashboard/Challenges/Workouts), je eigenem `NavigationStack` – bewusste Abweichung vom linearen Phase-Switch aus DLAMSD01 (dort war der Quiz-Flow linear, hier gibt es mehrere gleichrangige Bereiche). Tab-Bar bleibt System-Optik (Liquid Glass unter iOS 26), Screen-Inhalte laufen vollständig über das eigene Design-System (`DSWashedScreen`, `DSColor`, `DSFont`) – Grenzziehung in ADR 0005 festgehalten.
- Build für iOS-26-Simulator lief beim ersten Versuch erfolgreich durch (`BUILD SUCCEEDED`, keine Fehler/Warnings aus eigenem Code).

**Noch offen (nächste, jeweils eigens freizugebende Phasen):** Multi-Sport-Datenmodell (Phase B), Workout-Builder & Session-Flow (Phase C), Challenges & Auswertungen inkl. Heatmap/Top-5-Volumen/PR-Erkennung (Phase D), bidirektionaler HealthKit-Sync & Live Activity (Phase E).

## 2026-07-27 – Phase B: Datenmodell + eine echte Debugging-Sackgasse

Multi-Sport-SwiftData-Datenmodell umgesetzt (8 `@Model`-Klassen: Exercise, WorkoutPlan, PlannedExercise, WorkoutSession, SetLog, Challenge, ChallengeEnrollment, ChallengeProgressEntry) exakt nach dem von einem `Plan`-Agenten entworfenen Schema: `SchemaV1: VersionedSchema` + `WorkoutTrackerMigrationPlan`, asymmetrische Delete-Rules (`.nullify` von Exercise zu SetLog/PlannedExercise + Namens-Snapshot, `.cascade` von WorkoutSession zu SetLog/ChallengeProgressEntry), Seed-Katalog mit 14 Kraftübungen über ein einmaliges UserDefaults-Flag, Test-Target `WorkoutTrackerTests` in `project.yml` ergänzt.

**Die eigentliche Geschichte dieser Phase war aber ein Debugging-Marathon bei den ersten Unit-Tests.** Der erste Testlauf crashte reproduzierbar mit `EXC_BREAKPOINT` tief in `SwiftData.framework`, sobald ein Test `context.insert(...)` aufrief – bei jedem Test, unabhängig vom Modell. Die Fehlersuche verlief in mehreren, jeweils plausibel wirkenden, aber am Ende falschen Zwischenschritten:

1. Erste Vermutung: XCTest hostet Tests im App-Prozess, vielleicht kollidiert das mit SwiftData. Umstieg auf Swift Testing (`@Test`/`#expect`) – ein isolierter Minimal-Test lief tatsächlich durch. Sah nach der Lösung aus.
2. Beim Zurückbringen des vollen Schemas (`Schema(versionedSchema:)` + `migrationPlan:`) crashte es erneut. Zweite Vermutung: `VersionedSchema`/`migrationPlan` sind in diesem Xcode-26.0/iOS-26.0-Toolchain kaputt. Als "Fix" auf ein flaches `Schema` ohne Versionierung umgestellt und das als Xcode-Bug in ADR 0001 und im Code dokumentiert.
3. Beim Zusammenführen aller Testfälle in einer Suite mit gemeinsamem `init()` crashte es *wieder* – diesmal sogar mit dem flachen Schema. Das war der Punkt, an dem die bisherigen Erklärungen offensichtlich nicht mehr trugen.

Anstatt eine vierte Ad-hoc-Theorie nachzuschieben, wurde systematisch von der zuletzt funktionierenden Minimalversion aus jede einzelne Variable wieder einzeln zurückgebaut und jedes Mal neu verifiziert (Schema flach vs. versioniert, mit/ohne `migrationPlan`, `init()` vs. Inline-Erzeugung, XCTest vs. Swift Testing). Ergebnis: **Alle drei bisherigen Verdächtigen waren unschuldig.** Der eigentliche Fehler steckte im eigenen Testcode: Eine Hilfsfunktion gab nur `container.mainContext` zurück, ohne dass der Aufrufer den `ModelContainer` selbst weiter referenzierte – der Container wurde dealloziert, der zurückgegebene Context zeigte ins Leere, und der Crash trat beim ersten `insert`/`save` auf. Sobald der `ModelContainer` explizit im Aufrufer-Scope gehalten wird, laufen XCTest *und* Swift Testing *und* `VersionedSchema` *und* `migrationPlan` anstandslos durch – die ursprüngliche Architektur aus ADR 0001 (VersionedSchema von Anfang an) war die ganze Zeit richtig.

Konsequenz: Swift Testing wurde trotzdem beibehalten (kein Grund zurückzuwechseln, funktioniert einwandfrei und ist die modernere Wahl), `VersionedSchema`/`MigrationPlan` wurden vollständig wiederhergestellt, die fälschlich als "Toolchain-Bug" dokumentierten Code-Kommentare und der ADR-0001-Nachtrag wurden auf den echten Root Cause korrigiert. Lektion fürs weitere Vorgehen (relevant spätestens in Phase C/D, sobald mehr ViewModels eigene Contexts durchreichen): `ModelContext` und `ModelContainer` immer gemeinsam im gleichen Scope halten, nie nur den Context weiterreichen.

Alle 5 Unit-Tests grün (Seeding-Einmaligkeit, drei Cascade-/Nullify-Delete-Szenarien), App-Build + Simulator-Start ohne Regression verifiziert (Screenshot).
