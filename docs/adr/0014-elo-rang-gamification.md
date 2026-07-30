# 0014 – Elo-/Rang-Gamification: Formel, Decay und Comeback-Multiplikator
Datum: 2026-07-30 | Status: accepted

## Kontext
Lokales, single-device Gamification-Layer nach Trainingsabschluss: ein
League-of-Legends-artiges Rang-System (Bronze → Silver → Gold → Platin →
Diamond → Master → Challenger) über einen Elo-artigen Integer-Score, mit
Streak-Boost, Überlastungs-Bonus (Progressive Overload), Inaktivitäts-Verfall
und einer Comeback-Mechanik für Nutzer, die nach einer Pause unter ihren
früheren Bestwert gefallen sind. Explizit außerhalb des DLAMSD02-
Berichtsumfangs (private Erweiterung), folgt aber der üblichen
Engineering-Bar dieses Projekts (ADR, Tests, Review, eigener Branch/PR). Der
komplette Vergleich mit anderen Nutzern (Freundesliste/"My Gym") ist bewusst
eine spätere, separate Initiative - diese Entscheidung betrifft nur die
lokale, single-device Berechnung.

## Optionen (je Teilentscheidung)

**Persistenzform:** Singleton-Zeile `RankState` vs. Ableitung aus der
Session-Historie bei jedem Lesezugriff. Gewählt: Singleton (analog zur
Materialisierungs-Philosophie aus ADR 0002/0010) - Elo ist pfadabhängig
(Decay, Comeback-Peak), nicht ohne denselben Reconciliation-Lauf erneut aus
der reinen Historie ableitbar. Erste Singleton-Persistenz in diesem
Codebase (Challenges/PersonalRecords sind Mehrzeilen-Modelle) -
`RankState.fetchOrCreate(in:)` ist der einzige erlaubte Zugriffsweg.

**Decay-Berechnung:** Hintergrund-Job vs. lazy Reconciliation bei
Lesezugriff. Gewählt: lazy, zwei Trigger-Punkte (Session-Abschluss,
`ChallengesView.onAppear`) - kein Background-Task-Scheduling nötig, gleicher
Grundsatz wie ADR 0003 (kein eigener Timer/Task, wo eine Berechnung bei
Bedarf reicht).

**Überlastungs-Bonus:** absolute vs. relative Volumensteigerung ggü. der
letzten passenden Session. Gewählt: relativ (%), damit eine 20×10kg- und
eine 5×80kg-Übung bei gleicher prozentualer Steigerung gleich behandelt
werden, ohne jede Übung einzeln kalibrieren zu müssen. Nur Kraft-Sessions
(Cardio hat kein vergleichbares Volumen-Äquivalent, ADR 0009) - eine
Cardio-Overload-Metrik (z.B. Pace-Steigerung) ist explizit nicht Teil dieser
Entscheidung.

**Streak-Basis:** Challenge-Beitritt-gebunden (bestehendes
`ChallengeProgressEntry`, ADR 0002) vs. global über alle Sessions. Gewählt:
global, unabhängig von Challenge-Beitritt - jeder Kalendertag mit
mindestens einer abgeschlossenen Session (Kraft oder Cardio) zählt. Die
Kernlogik ("Rückwärtslauf über eindeutige Tage, 1-Tag-Gnadenfrist") wurde aus
`ChallengeInsights.currentStreakDays` in `DayStreakCalculator` ausgelagert
und wird von beiden Streak-Berechnungen gemeinsam genutzt statt dupliziert.

## Entscheidung

**Ränge:** Bronze (0) → Silver (500) → Gold (1000) → Platin (1600) →
Diamond (2200) → Master (2800) → Challenger (3400), Schwellen in
`RankTuning.tierThresholds`.

**Pro abgeschlossener Session:**
- Basis +15 Elo, nur an der ersten Session eines Kalendertags.
- Überlastungs-Bonus (nur Kraft): +2 Elo je begonnener 5%-Volumensteigerung
  ggü. der letzten passenden Session, gedeckelt bei +20/Übung, Summe über
  alle Übungen gedeckelt bei +40/Session. Gilt bei jeder Session (nicht
  tagesgated), da es die tatsächliche Leistung dieser Session widerspiegelt.
- Streak-Boost: +1 Elo je aktuellem globalem Streak-Tag, gedeckelt bei +20,
  nur an der ersten Session des Tages.
- Comeback-Multiplikator: ist `currentElo < peakElo` UND globaler Streak
  ≥ 7 Tage → 2× auf die Summe (Basis + Streak-Boost + Überlastungs-Bonus
  dieser Session). Kein persistiertes Flag - wird bei jedem Aufruf frisch aus
  `peakElo` (persistiert) und dem live berechneten Streak ermittelt, fällt
  automatisch auf 1× sobald `currentElo ≥ peakElo`, pausiert automatisch bei
  gebrochener Streak.
- `peakElo` = höchster je erreichter Wert, aktualisiert nach jedem Gewinn.

**Verfall:** −5 Elo pro komplett verpasstem Kalendertag, gefloort bei 0.

**Schlüssel-Invariante, die die Decay-Nachhol-Logik ohne erneutes
Durchsuchen der Session-Historie ermöglicht:** jeder Session-Abschluss läuft
IMMER durch `RankEngine.reconcile` (auch am selben Tag), das garantiert, dass
jeder Tag strikt zwischen `lastProcessedDay` und `today` zum Zeitpunkt der
Nachholung bereits als session-frei feststeht - sonst hätte eine frühere
Reconciliation `lastProcessedDay` schon vorangetrieben. Der Decay für diese
Lücke ist deshalb reine Arithmetik (`missedDays × 5`), kein Tag-für-Tag-Loop.
Bei reiner Decay-Nachholung (`ChallengesView.onAppear`, kein neuer
Session-Abschluss) rückt `lastProcessedDay` nur bis "gestern" vor, nie bis
"heute" - der heutige Tag ist noch offen und könnte später noch eine Session
bekommen. Das macht wiederholte Aufrufe am selben Tag idempotent.

**Frische `RankState`-Zeile:** `lastProcessedDay` wird bei der ersten Nutzung
bewusst auf "gestern" (relativ zu `today`) gesetzt, nicht auf "heute" - sonst
würde die allererste Session desselben Tages fälschlich als "heute schon
verarbeitet" gelten und ihren Basis-/Streak-Bonus verlieren.

Siehe `WorkoutTracker/Support/RankEngine.swift` für die autoritative
Implementierung.

**Nachtrag (Code-Review vor PR):** Trigger 1 (Session-Abschluss) reconciled
auf `trainedOn` (`session.startDate`), Trigger 2 (`ChallengesView.onAppear`)
auf echtes `.now` - bei einer über Mitternacht laufenden, offen gelassenen
Session könnte Trigger 1 mit einem `today` aufgerufen werden, das VOR dem
`lastProcessedDay` liegt, das Trigger 2 zwischenzeitlich bereits über den
echten Zeitpunkt vorangetrieben hat. `RankEngine.reconcile` clamped `today`
deshalb auf `max(todayStart, lastStart)`, bevor irgendetwas berechnet wird -
das verhindert, dass `lastProcessedDay` jemals rückwärts überschrieben wird
(was sonst zu doppeltem Decay beim nächsten Aufruf geführt hätte). Zusätzlich
ruft `WorkoutSession.updateRankProgress` `RankState.fetchOrCreate` jetzt mit
`today: trainedOn` statt dem Default `.now` auf, damit auch eine ganz neu
angelegte Zeile relativ zum tatsächlichen Trainingstag statt zur echten
Aufruf-Uhrzeit entsteht. Ebenfalls in diesem Zug behoben: importierte
HealthKit-Sessions (`HealthKitImportViewModel.importSession`) riefen
`updateRankProgress` bisher gar nicht auf - der Streak (der direkt aus der
Session-Historie lebt) zeigte dadurch einen aktiven Tag, während Rang/Elo
nichts davon wussten.

## Bekannte v1-Lücken (nicht in diesem PR behoben, bewusst zurückgestellt)

- **Zeitbasierte Bodyweight-Übungen** (z.B. Planks): Der Überlastungs-Bonus rechnet nur `reps × weightKg` (`ChallengeInsights.volumeByExercise`) - eine gehaltene Übung ohne Zusatzgewicht trägt praktisch nichts bei, unabhängig von der Dauer, da `SetLog` kein Dauer-Feld hat.
- **Kein Anti-Cheat/Plausibilitäts-Check für Session-Dauer.** Aktuell fließt die tatsächliche Trainingsdauer NICHT in die Elo-Formel ein - weder als Bonus noch als Plausibilitätsprüfung (z.B. "8 Übungen in 2:38 ist physisch unplausibel"). Das ist für v1 unkritisch, weil der Elo-Wert rein lokal ist und niemand außer einem selbst betrogen werden kann. **Sobald ein Social-/Vergleichs-Feature kommt (siehe [[dlamsd02-future-social-apple-first]]), MUSS das nachgezogen werden** - sonst kann sich jemand durch frei erfundene oder stark übertriebene Session-Daten (z.B. eine "10h Radtour" an einem entspannten Sonntag) unverdient hochranken, ohne dass ein Vergleich mit anderen noch aussagekräftig wäre. Eine reine Dauer-Belohnung wäre dabei genauso falsch wie eine reine Dauer-Plausibilitätsprüfung ohne Deckel - beides muss zusammen gedacht werden (gedeckelter Dauer-Bonus UND ein oberer Anschlag, der verhindert, dass sehr lange, wenig anstrengende Sessions unverhältnismäßig viel Elo bringen).

## Konsequenzen
- Positiv: reine, testbare Kernlogik ohne `ModelContext` (`RankEngine`); kein
  Background-Job; Decay-Nachholung ist O(1) arithmetisch statt O(Tage)
  Session-Requery; Streak-Berechnung ist projektweit einheitlich
  (`DayStreakCalculator`).
- Negativ/Risiken: Singleton-Zeile ist ein neues Persistenz-Muster in diesem
  Codebase - `fetchOrCreate` muss konsequent überall verwendet werden, nie
  ein direkter `RankState()`-Insert anderswo. Rang-Namen, Farbtöne und
  Schwellenwerte sind bewusste Platzhalter-Startannahmen, keine fertige
  Design-Entscheidung.
- Was würde uns zwingen, das zu revidieren? Ein künftiges Backend-/
  Social-Feature (bewusst deferred, siehe Projekt-Memory) bräuchte einen
  Sync-Mechanismus für `RankState` - reine Erweiterung, keine
  Struktur-Änderung der lokalen Reconciliation.

## Junior-Schutz-Fragen
- 10x mehr Daten? Eine einzige `RankState`-Zeile insgesamt, unabhängig von
  der Session-Anzahl - unproblematisch.
- Nutzer-Löschung? Lokale Daten, Löschen der App genügt.
- Migration weg? Eigenständiges SwiftData-Model, keine Fremdabhängigkeiten
  außer der Lesart von `WorkoutSession`-Historie zur Streak-/
  Überlastungs-Berechnung - leicht exportierbar/ersetzbar.
- Löst die einfachste Option (rein live berechnet, kein `RankState`) das
  Problem auch? Nein - Decay und Comeback-Peak sind pfadabhängig
  (abhängig von vergangenen Reconciliation-Läufen), nicht aus der reinen
  Session-Historie ableitbar, ohne denselben Lauf erneut durchzuführen.
