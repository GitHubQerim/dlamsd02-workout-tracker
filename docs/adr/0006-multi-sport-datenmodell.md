# 0006 – Multi-Sport-Datenmodell: ein WorkoutSession-Typ statt paralleler Entity-Hierarchien
Datum: 2026-07-26 | Status: accepted

## Kontext
Die App soll mehrere Sportarten abbilden (Kraft, Radfahren, Laufen, Tennis, Sonstiges), nicht nur klassisches Krafttraining mit Sätzen/Wiederholungen. Cardio-Sportarten brauchen andere Metriken (Distanz, Dauer, Puls) als Krafttraining (Sätze, Wiederholungen, Gewicht). Die Frage ist, wie dieser Unterschied im Datenmodell abgebildet wird, ohne die spätere HealthKit-Anbindung (Phase E) oder Challenge-Auswertungen (Phase D) unnötig zu verkomplizieren.

## Optionen
1. **Parallele Entity-Hierarchien pro Sportart** (z.B. `StrengthSession`, `CyclingSession`, `RunningSession` als getrennte SwiftData-Models) – Klar typisiert pro Sportart, aber: Challenges/Auswertungen (Streak, Wochenrückblick, Heatmap), die sportartübergreifend funktionieren müssen, müssten gegen mehrere Typen parallel abgefragt werden; jede neue Sportart bräuchte ein neues Model + neue Query-Pfade überall.
2. **Ein `WorkoutSession`-Typ mit `ActivityType` + optionalen Metrik-Blöcken (gewählt)** – Eine Entity, ein `ActivityType`-Enum-Feld (Kraft/Radfahren/Laufen/Tennis/Sonstiges), plus optionale, sich gegenseitig ausschließende Metrik-Blöcke: `setLogs: [SetLog]?` (Kraft) ODER `distance`/`duration`/`averageHeartRate` (Cardio). Challenges/Streaks/Heatmap fragen einheitlich gegen `WorkoutSession` ab, unabhängig von der Sportart.

## Entscheidung
Wir wählen ein einzelnes `WorkoutSession`-Model mit `ActivityType` und optionalen Metrik-Blöcken. Keine parallelen Entity-Hierarchien pro Sportart.

## Konsequenzen
- Positiv: Challenges, Streak-Logik, Wochenrückblick und Heatmap fragen gegen eine einzige Entity ab – neue Sportarten (z.B. Schwimmen später) sind nur ein neuer `ActivityType`-Case plus ggf. ein neuer optionaler Metrik-Block, keine neue Query-Infrastruktur.
- Negativ/Risiken: Die Entity trägt Felder, die je nach `ActivityType` ungenutzt/`nil` sind (etwas weniger strikte Typsicherheit als getrennte Models); UI-/Validierungslogik muss darauf achten, nur die zum `ActivityType` passenden Felder anzuzeigen/zu befüllen.
- Revidieren würde uns zwingen: Falls eine Sportart grundlegend andere Beziehungen bräuchte (z.B. Team-Mitspieler bei Tennis mit eigenem Beziehungsgraph), müsste für diesen Fall doch ein Sonderfall/Zusatz-Model ergänzt werden – aktuell nicht absehbar nötig.

## Junior-Schutz-Fragen
- 10x mehr Nutzer/Daten? Einzelnutzer-App, Datenmenge bleibt klein – keine Skalierungsfrage.
- Nutzer-Löschung? Rein lokale Daten, kein Extra-Mechanismus.
- Migration weg? Ein Wechsel zu getrennten Models pro Sportart wäre später als Datenmigration möglich (Filtern nach `ActivityType`, Aufteilen in neue Models), aber nicht der Plan.
- Löst die einfachste Option (getrennte Models pro Sportart) das Problem auch? Funktional ja, aber sie verletzt YAGNI in die andere Richtung (unnötige Vervielfachung von Typen für strukturell ähnliche Daten) und erschwert sportartübergreifende Auswertungen – deshalb die vereinheitlichte Variante gewählt.
