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
