# 0009 – Cardio-Segmente statt flacher Metrik-Felder
Datum: 2026-07-28 | Status: accepted

## Kontext
Der Workout-Editor zeigte für Cardio-Workouts (Radfahren/Laufen/Tennis/Sonstiges) dieselbe "Übung hinzufügen"-Flow wie Kraft-Workouts, obwohl der `Exercise`-Katalog kein `activityType` kennt, nur `muscleGroup`. Ergebnis: man konnte z.B. "Bizepscurls" zu einem Radfahren-Workout hinzufügen und bekam dafür ein unsinniges "Distanz (km)"-Feld angezeigt. ADR 0006 hatte für Cardio ursprünglich einen flachen, optionalen Metrik-Block direkt auf `WorkoutSession` (`distanceMeters`/`averageHeartRate`) sowie dieselben `PlannedExercise`-Zielfelder wie Kraft vorgesehen - beides erwies sich als zu grob: kein Platz für mehrere Abschnitte (Warmup/Sprint/Cooldown), keine sportartspezifischen Felder (Tennis hat z.B. keine sinnvolle Distanz-Metrik), und die künstliche Kopplung an den Kraft-Übungskatalog.

## Optionen
1. **Exercise-Katalog nach Sportart filtern** – `Exercise` bekommt ein `activityType`-Feld, der Picker filtert danach. Kleinste Änderung, löst aber nicht das eigentliche Problem: Cardio ist konzeptionell keine Liste benannter Übungen, sondern eine Abfolge von Abschnitten. Ein gefilterter Katalog-Eintrag "Radfahren" bliebe trotzdem nur EIN Eintrag - keine Mehrfach-Segmente (Warmup/Sprint/Cooldown) möglich, ohne den Katalog künstlich mit Duplikaten aufzublähen.
2. **Cardio-Segmente als eigenes Modellpaar (gewählt)** – Neue Modelle `PlannedSegment` (Planungsseite, Cardio-Äquivalent zu `PlannedExercise`) und `SegmentLog` (Session-Seite, Cardio-Äquivalent zu `SetLog`), komplett entkoppelt vom `Exercise`-Katalog. `Workout.segments`/`WorkoutSession.segmentLogs` laufen parallel zu den unangetasteten `plannedExercises`/`setLogs` - Kraft und Cardio nutzen ab jetzt zwei unabhängige Listen statt geteilter nilable Felder.
3. **Nur das flache Feld-Paar erweitern** (z.B. `distanceMeters`/`durationSeconds` direkt auf `Workout`/`WorkoutSession` belassen, nur pro Sportart maskieren) – am wenigsten Aufwand, löst aber die vom Nutzer explizit gewünschte Mehrsegment-Fähigkeit (Warmup/Sprint/Cooldown) nicht.

## Entscheidung
Wir führen `PlannedSegment`/`SegmentLog` als eigenes, vom `Exercise`-Katalog unabhängiges Modellpaar ein (Option 2). `ActivityType.cardioFieldOptions` steuert pro Sportart, welche Felder (Distanz/Dauer) angezeigt werden - z.B. zeigt Tennis nur Dauer, kein Distanz-Feld. Kraft bleibt zu 100% unverändert (`Exercise`, `PlannedExercise`, `SetLog`, `ExercisePickerView`).

**Neue Invariante beim Speichern:** `WorkoutEditorViewModel.save()` leert bei jedem Speichern explizit die gerade inaktive Seite komplett (alle `plannedExercises`, wenn Cardio aktiv ist; alle `segments`, wenn Kraft aktiv ist) - ein architecture-reviewer-Pass fand sonst folgenden Bug: Schaltet man einen bestehenden Kraft-Plan auf Radfahren um und speichert, blieben ohne diese explizite Bereinigung die alten `PlannedExercise`-Zeilen tot an `plan.plannedExercises` hängen, weil `save()` nur die jeweils aktive Liste synct.

**Puls bleibt bewusst flach:** `WorkoutSession.averageHeartRate` wird NICHT segmentiert - Puls ist in dieser manuell erfassten App (kein HealthKit-Live-Tracking) nicht sinnvoll pro Segment erfassbar, ein Wert pro ganzer Session reicht. `WorkoutSession.distanceMeters` (gespeichertes Feld) entfällt dagegen komplett zugunsten einer berechneten `totalDistanceMeters` (Summe über `segmentLogs`).

## Konsequenzen
- Positiv: Cardio-Workouts sind nicht mehr künstlich an den Kraft-Übungskatalog gekoppelt; Mehrsegment-Training (Warmup/Sprint/Cooldown) ist von Anfang an möglich; sportartspezifische Felder verhindern unsinnige Kombinationen (z.B. "Distanz" bei Tennis).
- Negativ/Risiken: Zwei zusätzliche Modelle, zwei zusätzliche parallele Relationships auf `Workout`/`WorkoutSession` - etwas mehr Code als eine rein flache Lösung. Jeder künftige Code-Pfad, der `activityType` ändert oder einen Plan speichert, MUSS über `WorkoutEditorViewModel.save()` laufen, sonst wird die "inaktive Seite leeren"-Invariante umgangen.
- Was würde uns zwingen, das zu revidieren? Sollte sich zeigen, dass Cardio-Sessions doch pro Segment Puls/weitere Metriken brauchen (z.B. durch echte HealthKit-Anbindung in Phase E), müsste `SegmentLog` um weitere Felder erweitert werden - reine Additive, keine Struktur-Änderung.

## Junior-Schutz-Fragen
- 10x mehr Daten? Wenige Segmente pro Workout/Session (typisch 2-4), unproblematisch für Einzelnutzer-Volumen.
- Nutzer-Löschung? Rein lokale Daten, kein Extra-Mechanismus.
- Migration weg? `PlannedSegment`/`SegmentLog` sind eigenständige SwiftData-Models, leicht ersetzbar; kein `SchemaV2` nötig, da noch keine echten Nutzerdaten existieren.
- Löst die einfachste Option (Exercise-Katalog filtern) das Problem auch? Technisch könnte man damit "einen" Cardio-Eintrag pro Workout korrekt anzeigen, aber sie löst nicht die vom Nutzer gewünschte Mehrsegment-Fähigkeit und hält die künstliche Kopplung an den Kraft-Katalog aufrecht - deshalb bewusst nicht die einfachste, sondern die strukturell passende Option gewählt.
