# 0007 – ID+Snapshot-Hybrid statt reines String-Matching für Programm-Tag-Auflösung
Datum: 2026-07-27 | Status: accepted

## Kontext
Das neue `WorkoutProgram`-Feature verbindet mehrere `Workout`s zu benannten Tagen (z.B. "Day 1" = Push, "Day 2" = Pull) und muss daraus ableiten können, welcher Tag zuletzt gemacht wurde und welcher als Nächstes dran ist ("weiter mit Day 2"). Dafür braucht `WorkoutSession` einen Verweis zurück auf den Programm-Tag, aus dem sie gestartet wurde.

## Optionen
1. **Reines String-Matching** – `WorkoutSession` speichert nur `programName: String?` und `programDayLabel: String?`. Die Auflösung sucht die letzte Session mit passendem Namen/Label und matched das gegen die aktuellen Einträge des Programms. Einfachste Implementierung, aber: weder `WorkoutProgram.name` noch `WorkoutProgramEntry.dayLabel` sind unique-constrained. Zwei gleichnamige Programme (oder zwei Tage mit demselben Label) hätten sich bei der Zuordnung gegenseitig kontaminiert, und ein umbenannter `dayLabel` hätte zu einem *stillen* Fallback auf den ersten Eintrag geführt – ohne Fehler, aber falsch.
2. **ID+Snapshot-Hybrid (gewählt)** – `WorkoutProgramEntry` bekommt eine eigene `id: UUID`. `WorkoutSession.programEntryID: UUID?` ist der primäre Schlüssel für die Zuordnung; `programName`/`programDayLabel` bleiben zusätzlich als reine Anzeige-Snapshots (analog zum bestehenden `exerciseName`-Snapshot-Muster auf `PlannedExercise`/`SetLog`), damit die "Letztes Training"-Anzeige auch dann noch lesbar ist, wenn der Tag später gelöscht wurde.
3. **Live-Relationship statt Snapshot** – `WorkoutSession` hält einen direkten `@Relationship`-Link auf `WorkoutProgramEntry`. Würde Umbenennungen automatisch korrekt anzeigen, aber: ändert sich das Programm rückwirkend (Tag gelöscht, Reihenfolge geändert), würde sich auch die Anzeige *vergangener* Sessions rückwirkend ändern – nicht gewünscht, ein Protokoll soll den Zustand zum Zeitpunkt der Session festhalten.

## Entscheidung
Wir nutzen den ID+Snapshot-Hybrid (Option 2). Das ist die vom `architecture-reviewer` benannte Korrektur der ursprünglichen Idee (reines String-Matching, Option 1) – die Zuordnung läuft über `WorkoutProgramEntry.id`, nicht über Namen, während die Anzeige weiterhin auf robusten Text-Snapshots basiert statt auf einem Live-Link, der sich rückwirkend ändern könnte.

## Konsequenzen
- Positiv: Zuordnung ist eindeutig und stabil, auch bei gleichnamigen Programmen/Tagen oder späteren Umbenennungen. Anzeige vergangener Sessions bleibt historisch korrekt (Snapshot statt Live-Link).
- Negativ/Risiken: Drei Felder (`programEntryID`, `programName`, `programDayLabel`) statt eines – muss dokumentiert bleiben, warum sie divergieren dürfen (Kommentar direkt an den Feldern in `SchemaV1+WorkoutSession.swift`), sonst wirkt es wie Redundanz statt Absicht. Wird der zuletzt gemachte Tag zwischenzeitlich aus dem Programm entfernt, degradiert die Auflösung auf den ersten Eintrag (`WorkoutTracker/Support/WorkoutProgramNextEntry.swift`) statt abzustürzen – bewusster Fallback, kein Edge-Case-Crash.
- Revidieren würde uns zwingen: Falls Workouts/Tage künftig plattformübergreifend synchronisiert werden (CloudKit o.ä.), müsste geprüft werden, ob `UUID`-Kollisionen über Geräte hinweg ausgeschlossen sind – aktuell rein lokal, kein Thema.

## Junior-Schutz-Fragen
- 10x mehr Daten? Ein `programEntryID`/zwei Strings zusätzlich pro Session – linear, keine Skalierungsfrage bei Einzelnutzer-Volumen.
- Nutzer-Löschung? Lokale Daten, Löschen der App genügt.
- Migration weg? Alle drei Felder sind einfache, optionale Skalare auf `WorkoutSession` – leicht entfernbar/ersetzbar, keine Fremdschlüssel-Abhängigkeit nach außen.
- Löst die einfachste Option (reines String-Matching) das Problem auch? Nein – sie hätte bei Namensgleichheit oder Umbenennung *unbemerkt* falsch zugeordnet, was schlimmer ist als ein sichtbarer Fehler. Deshalb bewusst nicht die einfachste Option.
