# 0015 – Heatmap-Vollständigkeit: Workout-Abschluss ODER geschlossener Move-Ring
Datum: 2026-08-12 | Status: accepted

## Kontext
Die Trainings-Heatmap färbte Tage bisher rein nach Anzahl abgeschlossener `WorkoutSession`s desselben Kalendertags (0/1/2/3+ → 4 Farbstufen, `HeatmapColorMapping.swift`). Ein einzelnes, hartes Workout erreichte nie die volle Farbe - dafür waren 3+ Sessions am selben Tag nötig. Das wirkte demotivierend für Nutzer, die typischerweise ein Workout pro Tag loggen. Gleichzeitig gibt es bisher kein Signal für ehrliche Alltagsbewegung an trainingsfreien Tagen - solche Tage waren immer leer, unabhängig davon, wie aktiv der Tag tatsächlich war.

## Optionen
1. **Reiner Kcal-Schwellwert aus Health** (z.B. "voll ab 400 kcal Tagesverbrauch") - naheliegend, aber willkürlich: ein selbst erfundener Schwellwert passt nicht zu jedem Körper/Trainingsstand und reproduziert exakt das ursprüngliche Problem (ein anstrengendes Workout mit moderatem Kcal-Wert würde wieder nicht "voll" zählen).
2. **Bedingungslos "voll" ab 1 Session + Apples eigener Move-Ring-Status (`activeEnergyBurned >= activeEnergyBurnedGoal`) als Ersatzsignal an trainingsfreien Tagen.** Nutzt einen bereits von Apple personalisierten Schwellwert statt eines selbst erfundenen, und trennt "hast du trainiert" (bedingungslos) von "warst du trotzdem aktiv" (Move-Ring).

## Entscheidung
Wir wählen **Option 2**. Ein Tag ist "voll" (Akzentfarbe), wenn `count >= 1` (mindestens eine abgeschlossene Session) ODER `moveRingClosed == true` (Move-Ring an einem Tag ohne Session geschlossen). `DayCount` bekommt dafür additiv ein `moveRingClosed: Bool`-Feld statt `count` zu einem Enum zu erweitern - kein Zustandsraum größer als 2, ein Enum wäre hier Overengineering gewesen. Der HealthKit-Fetch (`HealthKitServicing.fetchClosedMoveRingDates(since:calendar:)`) liefert reine `Date`s, kein `HKActivitySummary` überschreitet die Protokoll-Grenze (ADR 0011). Die Merge-Logik (`ChallengeInsights.applyingMoveRingSignal`) bleibt eine reine, synchron testbare Funktion, getrennt vom HealthKit-Fetch selbst - dieselbe Trennung wie bei `EnergyEstimator`.

**Bewusst akzeptierter Informationsverlust:** die bisherige 4-Stufen-Farbskala (0/1/2/3+) wird binär (voll/leer). Ein Tag mit 2 Sessions sieht jetzt genauso aus wie ein Tag mit 1 Session - die "mehr Sessions = mehr Farbe"-Nuance ist absichtlich weg, weil sie genau die Ursache des ursprünglichen Problems war.

**Fehlerpfad-Vertrag:** ein fehlender/verweigerter/fehlerhafter Move-Ring-Fetch degradiert immer still auf "nur Session-Farbe" (`try?`, leeres `Set<Date>`) - nie ein Fehlerbanner, nie ein blockierter Snapshot-Schreibvorgang. Analog zu `finishSession()`s bestehendem Umgang mit `fetchLatestBodyWeightKg`.

**Fire-and-Forget statt blockierendem Async-Umbau:** `WidgetSnapshotRefresher.refresh(context:)` bleibt synchron. Der Move-Ring-Fetch läuft als eigener, nicht-blockierender `Task` daneben, der den bereits geschriebenen Snapshot nachträglich patcht und ein zweites Timeline-Reload anstößt. Ein architecture-reviewer-Durchgang wies zu Recht darauf hin, dass ADR 0013 "kurzzeitig veraltete" Widget-Daten bereits als Normalfall akzeptiert - ein kompletter Async-Umbau von `refresh` hätte einen Ripple-Effekt bis in `HealthKitImportViewModel.importSession` (aktuell synchron) und dessen View/Tests ausgelöst, für einen Konsistenz-Gewinn, den das eigene ADR 0013 gar nicht fordert.

## Konsequenzen
- Positiv: Löst das eigentliche Nutzerproblem (hartes Workout zählt nicht "voll") ohne einen willkürlichen Kcal-Wert zu erfinden. HealthKit-Grenze bleibt sauber (ADR 0011), kein Ripple-Effekt in bestehenden synchronen Aufrufern.
- Negativ/Risiken: Neuer Read-Scope (`HKObjectType.activitySummaryType()`). Bereits verbundene Bestandsnutzer werden nicht aktiv zur erneuten Autorisierung aufgefordert - der "Verbinden"-Button reagiert nicht auf "neuer Scope seit letzter Freigabe". Für diese Nutzer bleibt `closedMoveRingDates` bis zum nächsten manuellen "Verbinden"-Tap leer (kein Crash, nur unsichtbar). `HKActivitySummaryQuery` ist die zweite Stelle im Projekt, die einen Continuation-Wrapper statt eines modernen async-Descriptors braucht (neben `attachEnergy`).
- Was würde uns zwingen, das zu revidieren? Wenn Nutzer die verlorene Mehrstufigkeit (1 vs. 2+ Sessions) konkret vermissen, wäre ein separates visuelles Signal (z.B. ein Badge für "Extra-Einsatz"-Tage) statt der ursprünglichen Farbskala der nächste Schritt - keine Rückkehr zum alten "3+ für volle Farbe"-Modell.

## Nachtrag (2026-08-12, nach echtem Gerätetest)
Der ursprüngliche binäre Ansatz ("Session ODER Move-Ring → gleiche volle Farbe") wurde nach dem ersten echten Gerätetest revidiert: auf der echten Heatmap leuchteten deutlich mehr Kacheln voll als tatsächlich geloggte Workouts stattfanden, weil viele Tage allein durch den geschlossenen Move-Ring "voll" wurden - der Nutzer konnte nicht mehr unterscheiden, welche Tage echtes Training waren. Die Skala ist jetzt dreistufig: `count >= 1` → volle Akzentfarbe (unverändert), `count == 0 && moveRingClosed` → mittlere Stufe (`DSColor.green700`, vorher ungenutzt), sonst leer. Der Fehlerpfad-Vertrag, die HealthKit-Grenze und der Fire-and-Forget-Mechanismus bleiben unverändert - nur `HeatmapColorMapping.color(for:)` und dessen Tests wurden angepasst.

## Junior-Schutz-Fragen
- 10x mehr Nutzer/Daten? Einzelnutzer-App, eine Query pro Snapshot-Refresh über ein festes 20-Wochen-Fenster, unabhängig von der Gesamt-Session-Historie.
- Nutzer-Löschung (DSGVO)? `closedMoveRingDates` ist eine reine, nicht persistierte Ableitung aus Health-Daten, die der Nutzer selbst über iOS-Einstellungen kontrolliert - keine zusätzliche eigene Datenkopie mit Löschbedarf über den bereits bestehenden Widget-Snapshot hinaus.
- Migration weg von Move-Ring als Signal? Da nur `Set<Date>` über die Protokoll-Grenze kommt, ließe sich die Datenquelle (z.B. auf einen anderen HealthKit-Wert) austauschen, ohne `ChallengeInsights`/`HeatmapColorMapping`/die Views anzufassen.
- Löst die einfachste Option (fester Kcal-Schwellwert) das Problem auch? Nein - sie verlagert das ursprüngliche Problem nur auf einen neuen, selbst erfundenen Schwellwert statt Apples bereits personalisiertem Ziel zu vertrauen.
