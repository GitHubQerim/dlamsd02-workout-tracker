# Journal-Kontext

## Kurs
DLAMSD02 – Apple Mobile Solution II (IU Internationale Hochschule)

## Aufgabenstellung
Aufgabenstellung 3: "Challenge accepted! Entwickle Deine individuelle Tracking-App" – interaktive Tracking-App für die iOS-Plattform, Anwendungsbereich frei wählbar (Nachhaltigkeit, Gesundheit, Allgemeinbildung usw.).

Gewählt: **Multi-Sport-Workout-Tracker** (Kraft, Radfahren, Laufen, Tennis, Sonstiges) – die App soll auch real im eigenen Training genutzt werden, nicht nur als Kurs-Artefakt.

## Mindestanforderungen (aus der Aufgabenstellung)
- [ ] App zeigt beim Start den aktuellen Status im Hinblick auf zu erreichende Ziele (Challenges) an
- [ ] Über passende UI-Elemente kann sich der Nutzer eine Liste mit auswählbaren Challenges anzeigen lassen
- [ ] Nutzer kann sich für eine Challenge einschreiben
- [ ] Erzielte Leistungen in einer Challenge können protokolliert werden
- [ ] Für jede Challenge kann eine Detailansicht mit den bisher erzielten Leistungswerten angezeigt werden
- [ ] Die aktuellen Leistungswerte werden gespeichert
- [ ] Die App bietet (mindestens) ein darüberhinausgehendes Feature an

## Gewählter Funktionsumfang
- **Kern:** Workouts selbst erstellen, Session-Flow mit Sätze-Abhaken, Pausen-Timer zwischen Sätzen, Gesamt-Trainingszeit (wall-clock-basiert, siehe ADR 0003).
- **Challenges:** Streak-basiert, automatisch aus geloggten Workout-Sessions abgeleitet, aber als materialisierter `ChallengeProgressEntry`-Log persistiert (siehe ADR 0002) – keine rein berechnete Anzeige.
- **Pflicht-Zusatzfeatures (mehr als das geforderte Minimum von einem):**
  - Wochenrückblick mit Mini-Chart
  - Heatmap im Contribution-Style (ein Aggregat pro Tag)
  - Top-5-Übungen nach Volumen (Sätze × Wiederholungen × Gewicht, nicht nach Häufigkeit)
  - Personal-Record-Erkennung bei Session-Abschluss, persistiert
- **Später (eigene Phasen/Pläne):** bidirektionaler Apple-HealthKit-Sync (Kraft-Sessions schreiben, Cardio-Einheiten importieren, inkl. Dedup-Logik), Live Activity für den laufenden Timer (Stretch, niedrigere Priorität).
- **Kür, nur falls Zeit reicht:** Übungs-Infokarte mit kurzem Ausführungshinweis pro Übung (`icon-info`).

## Architektur-Entscheidungen
Siehe `docs/adr/` für die vollständige Begründung je Entscheidung:
- 0001 – SwiftData statt UserDefaults
- 0002 – Materialisierter Challenge-Progress-Log statt reiner Berechnung
- 0003 – Wall-Clock-basiertes Timer-Design
- 0004 – MVVM statt TCA (Bestätigung trotz größerem Scope)
- 0005 – iOS 26 als Deployment-Target + Abgrenzung Liquid Glass vs. eigenes Design-System
- 0006 – Multi-Sport-Datenmodell: ein `WorkoutSession`-Typ statt paralleler Entity-Hierarchien
- 0011 – HealthKitService-Architektur: erster echter Service statt zustandsloser Support-Extensions
- 0012 – HealthKit-Dedup-/Sync-Strategie (ausschließlich über `HKWorkout.uuid`)

Ein `architecture-reviewer`-Agent hat die Grundsatzentscheidungen vor der Umsetzung geprüft (u.a. den materialisierten Challenge-Log und das Wall-Clock-Timer-Design als Korrekturen beigetragen).

## Herkunft des Design-Systems
Das verwendete Design-System **"GreenDarkFitness"** (near-black UI, ein Mint-Grün-Akzent `#2FB19B`, Violett nur für negative Werte, Manrope-Font) stammt aus dem Vorgängerprojekt `dlamsd01-fitness-quiz` (DLAMSD01, bereits abgegeben). Es wurde dort selbst schon als Zweitverwendung eingesetzt: ursprünglich für eine Workout-Tracking-App entworfen, für den Quiz-Kontext von DLAMSD01 uminterpretiert (Violett statt Rot für falsche Antworten). In DLAMSD02 kommt es nun in seinem ursprünglich gedachten Einsatzzweck zum Einsatz.

Die Wiederverwendung ist **bewusst, nicht zufällig**, und wird im DLAMSD02-Projektbericht offengelegt: keine Code-Duplikation als Zufall, sondern gezielte Weiterentwicklung eines bestehenden Artefakts (inkl. der nötigen Swift-6/iOS-26-Anpassungen, siehe `docs/journal.md`) – ein konkreter Beleg für das Bewertungskriterium "Transfer".

## Bewertungskriterien (Prüfungsleitfaden)
Transfer, Dokumentation, Ressourcen, Prozess, Kreativität, Qualität – jeweils fortlaufend dokumentieren, insbesondere Prozess (laufendes Journal) und Kreativität (Multi-Sport-Ansatz, Design-System-Herkunft und -Weiterentwicklung, Auswertungs-Features).
