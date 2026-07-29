# 0010 – Personal-Record-Erkennung als eigener materialisierter Log
Datum: 2026-07-28 | Status: accepted

## Kontext
Phase D verlangt (siehe `docs/journal-kontext.md`) eine "Personal-Record-Erkennung bei Session-Abschluss, persistiert" - analog zur bereits in ADR 0002 etablierten Materialisierungs-Philosophie für Challenge-Fortschritt. Ein PR ("neues Gewichtsmaximum für eine Übung") ist im Kern die gleiche Art von Ableitung wie ein Challenge-Progress-Eintrag: aus den ohnehin geloggten `SetLog`s berechenbar, aber laut Aufgabenstellung wörtlich zu protokollieren.

## Optionen
1. **Rein berechnet** – Bei jeder Anzeige wird pro Übung das Maximalgewicht über alle `SetLog`s aller abgeschlossenen Sessions live ermittelt. Einfachste Umsetzung, aber (wie schon in ADR 0002 verworfen) kein "Protokoll", nur eine Ableitung - und bei wachsender Session-Historie eine zunehmend teurere Live-Aggregation.
2. **Eigenes materialisiertes Modell `PersonalRecord` (gewählt)** – Beim Session-Abschluss wird pro Übung geprüft, ob das in dieser Session erzielte Maximalgewicht den bisherigen Bestwert übertrifft; wenn ja, wird ein `PersonalRecord`-Eintrag (Übungsname, Gewicht, Wdh., Datum, auslösende Session) persistiert. Anzeige liest aus diesem Log.
3. **PR als Spezialfall von `ChallengeProgressEntry`** – PRs über das bestehende Challenge-Modell abbilden (z.B. eine "PR-Challenge" pro Übung). Verworfen: `Challenge`/`ChallengeProgressEntry` sind für Streak/Frequenz-Zählwerte modelliert (`targetValue: Int`, `value: Double` als reiner Zähler), nicht für "Gewicht + Wiederholungen einer bestimmten Übung" - eine Zweckentfremdung, die das bestehende Modell verbiegen würde statt ein passendes, eigenes zu nutzen.

## Entscheidung
Wir führen `PersonalRecord` als eigenes, `WorkoutSession`-Cascade-Modell ein (Option 2), erkannt und persistiert in `WorkoutSession.detectAndPersistPersonalRecords(in:)`, aufgerufen aus `WorkoutSessionViewModel.finishSession()` - gleicher Aufrufpunkt wie die Challenge-Progress-Materialisierung.

**Vergleichsregel:** pro Übung wird das in der jeweiligen Session erzielte Maximalgewicht (`SetLog.weightKg`, unabhängig vom `isCompleted`-Häkchen - siehe Nachtrag zu ADR 0002) gegen den aktuellen Bestwert für diesen Übungsnamen verglichen (`FetchDescriptor<PersonalRecord>` mit Skalarfeld-Predicate auf `exerciseName`, sortiert absteigend nach `weightKg`, `fetchLimit = 1` - kein Relationship-Predicate, ADR-0001-sicher). Echt größer (oder noch kein Eintrag) → neuer Rekord. Gleiches oder niedrigeres Gewicht → kein neuer Eintrag.

**Cascade-Entscheidung:** `WorkoutSession.personalRecords` ist `.cascade` (wie `challengeProgressEntries`) - ein PR ohne seine auslösende Session wäre ein Phantom-Rekord, gleiches Argument wie ADR 0002.

**Scope-Entscheidung:** Kraft-only (`activityType.usesSetLogs`). Cardio (`SegmentLog`) hat kein Gewicht/Wiederholungen-Äquivalent (ADR 0009) - eine "Cardio-PR" (z.B. schnellste Zeit, längste Distanz) wäre ein eigenes, andersartiges Konzept und explizit nicht Teil dieser Entscheidung.

## Konsequenzen
- Positiv: Konsistent mit dem etablierten Materialisierungs-Muster aus ADR 0002; PR-Historie bleibt korrekt, auch wenn sich spätere Sessions/Berechnungslogik ändern; O(1) statt O(n) Vergleich pro Übung dank persistiertem Bestwert statt Live-Scan aller Sessions.
- Negativ/Risiken: Ein weiteres Modell, ein weiterer Materialisierungs-Aufrufpunkt, der synchron zum Session-Abschluss gehalten werden muss (gleiches Risiko wie bei `ChallengeProgressEntry`, ADR 0002).
- Was würde uns zwingen, das zu revidieren? Sollte eine echte HealthKit-Anbindung (Phase E) eigene, genauere Gewichtsdaten liefern, müsste die Vergleichsregel ggf. HealthKit-Quellen mit einbeziehen - reine Erweiterung, keine Struktur-Änderung.

## Junior-Schutz-Fragen
- 10x mehr Daten? Ein PR-Eintrag nur bei tatsächlicher Verbesserung (nicht pro Session) - deutlich seltener als Sessions selbst, unproblematisch.
- Nutzer-Löschung? Lokale Daten, Löschen der App genügt.
- Migration weg? Eigenständiges SwiftData-Model ohne Fremdabhängigkeiten außer der Cascade-Relation - leicht exportierbar/ersetzbar.
- Löst die einfachste Option (rein berechnet) das Problem auch? Technisch ja, aber nicht die Bewertungsanforderung ("persistiert") - deshalb bewusst die zweiteinfachste, nicht die einfachste Option (gleiches Argumentationsmuster wie ADR 0002).
