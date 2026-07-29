# 0002 – Materialisierter Challenge-Progress-Log statt reiner Berechnung
Datum: 2026-07-26 | Status: accepted

## Kontext
Aufgabenstellung 3 verlangt explizit: "Erzielte Leistungen in einer Challenge können protokolliert werden." Unsere Challenges (Streaks, z.B. "X Tage am Stück trainieren") leiten sich aber aus den ohnehin geloggten Workout-Sessions ab – die naheliegende Umsetzung wäre, den Fortschritt bei jedem Anzeigen live aus der Session-Historie zu berechnen, ohne ihn separat zu speichern.

## Optionen
1. **Rein berechnet** – Bei jedem Öffnen einer Challenge-Detailansicht wird der Fortschritt live aus `WorkoutSession`-Query abgeleitet. Einfachste Implementierung, aber: nichts wird tatsächlich "pro Challenge" gespeichert – im Bericht schwer als "Protokollieren erzielter Leistungen in einer Challenge" zu begründen.
2. **Materialisiert (gewählt)** – Beim Abschluss einer Session, die zu einer eingeschriebenen Challenge beiträgt, wird ein persistierter `ChallengeProgressEntry` (Datum, Wert, Referenz auf die auslösende Session) erzeugt. Fortschrittsanzeige liest aus diesem Log, nicht aus einer Live-Neuberechnung.

## Entscheidung
Wir materialisieren den Fortschritt. Das ist die vom `architecture-reviewer` benannte Korrektur der ursprünglichen Idee (rein berechnet) – geringer Mehraufwand, aber ein echter, prüfbarer Log pro Challenge statt einer Ableitung, die ein Prüfer als "nicht wirklich protokolliert" werten könnte.

## Konsequenzen
- Positiv: Erfüllt die Mindestanforderung wörtlich und nachweisbar; Progress-Historie bleibt auch dann korrekt, wenn sich die Berechnungslogik einer Challenge später ändert (kein rückwirkendes Neuberechnen nötig).
- Negativ/Risiken: Zwei Wahrheitsquellen (Session-Log und Challenge-Progress-Log) müssen synchron gehalten werden – Erzeugung des Progress-Eintrags muss zuverlässig an den Session-Abschluss gekoppelt sein (ein Punkt für sorgfältiges Testen in Phase C/D).
- Revidieren würde uns zwingen: Wenn sich herausstellt, dass Challenge-Regeln sich zu häufig ändern und ein Nachziehen bestehender Progress-Einträge nötig wird, müsste eine Revalidierungs-/Neuberechnungs-Routine ergänzt werden.

## Junior-Schutz-Fragen
- 10x mehr Daten? Ein Progress-Eintrag pro Session pro betroffener Challenge – linear zur Session-Anzahl, unproblematisch für Einzelnutzer-Volumen.
- Nutzer-Löschung? Lokale Daten, Löschen der App genügt.
- Migration weg? `ChallengeProgressEntry` ist ein einfaches, eigenständiges SwiftData-Model – leicht exportierbar/ersetzbar.
- Löst die einfachste Option (rein berechnet) das Problem auch? Technisch ja, aber nicht die Bewertungsanforderung – deshalb bewusst die zweiteinfachste, nicht die einfachste Option gewählt.

## Nachtrag 2026-07-28 (Phase D): Zähl-Regeln, Enrollment-Gating, Konsistenz mit `previousAttempt()`

Beim Verdrahten der eigentlichen Materialisierung (`WorkoutSession.materializeChallengeProgress(in:)`, aufgerufen aus `finishSession()`) wurden drei bisher offene Detailfragen entschieden:

**Streak- vs. Frequenz-Zählregel:** `streakTage`-Challenges bekommen höchstens einen `ChallengeProgressEntry` pro Kalendertag (Streak zählt Tage, nicht Sessions - zwei Sessions am selben Tag dürfen die Streak nicht doppelt voranbringen). `frequenzProWoche`-Challenges bekommen dagegen einen Eintrag pro abgeschlossener Session ohne Dedup (Frequenz zählt tatsächliche Trainingseinheiten pro Woche). Jede Sportart (Kraft und Cardio) zählt gleichermaßen für beide Typen.

**Enrollment-Gating ohne rückwirkendes Nachtragen/Reset:** `ChallengeEnrollment` hat bewusst keine Beziehung zu `ChallengeProgressEntry` (dieser referenziert nur `Challenge` + `triggeringSession`). Eine Challenge bekommt also nur dann einen neuen Eintrag, wenn im Moment des Session-Abschlusses mindestens eine Anmeldung existiert - kein rückwirkendes Nachtragen für Sessions vor dem Beitritt, kein Reset des bisherigen Logs bei Verlassen und späterem erneutem Beitritt. Das ist die einfachste korrekte Lesart des bestehenden Schemas (kein rückwirkendes Neuberechnen, im Sinne der ursprünglichen Entscheidung oben) und wurde bewusst nicht um eine Enrollment→ProgressEntry-Beziehung erweitert, um diese Garantie zu erzwingen - YAGNI, solange kein Bedarf für ein "sauberes" Zurücksetzen erkennbar ist.

**"Alle SetLogs zählen, nicht nur abgehakte" als projektweite Konsistenzregel:** `WorkoutSessionViewModel.previousAttempt()` filtert bereits seit Phase C bewusst nicht nach `SetLog.isCompleted` - alle geloggten Sätze zählen für den "Letztes Mal"-Vergleich. Personal-Record-Erkennung (ADR 0010) und Top-5-Volumen-Auswertung übernehmen dieselbe Regel, statt für "was zählt als geloggter Satz" zwei unterschiedliche, unbegründete Antworten im selben Projekt zu haben.

**Bekannte, bewusst nicht gelöste Einschränkung:** Tagesgrenzen werden über `Calendar.current`/Gerätezeitzone bestimmt - bei einem Zeitzonenwechsel während einer laufenden Streak könnte ein Tag doppelt oder gar nicht gezählt werden. Für ein Einzelnutzer-Kursprojekt ohne Reisenutzung akzeptiert, keine eigene Lösung dafür.
