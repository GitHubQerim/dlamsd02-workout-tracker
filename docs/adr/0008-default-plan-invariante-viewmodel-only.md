# 0008 – Default-Plan-Invariante bleibt ViewModel-only, keine DB-Constraint
Datum: 2026-07-27 | Status: accepted

## Kontext
Genau ein `WorkoutProgram` darf gleichzeitig `isDefault == true` sein (der "Standard-Plan", der auf dem Dashboard die "weiter mit Day N"-Aktion zeigt). SwiftData kennt keine eingebaute "at most one row with flag=true"-Constraint auf Modell-Ebene.

## Optionen
1. **DB-seitige Durchsetzung** – z.B. über ein zusätzliches Singleton-Referenz-Objekt ("aktueller Standard-Plan"), das statt eines Bool-Flags pro Programm eine einzige, eindeutige Referenz hält. Würde die Invariante strukturell erzwingen, bräuchte aber ein zusätzliches Modell nur für diesen einen Zweck und eine Migration bestehender `isDefault`-Semantik dorthin – Mehraufwand ohne echten Mehrwert bei der aktuellen App-Größe.
2. **ViewModel-only (gewählt)** – `WorkoutProgramEditorViewModel.setDefault(_:in:)` setzt vor jedem Speichern alle anderen Programme auf `isDefault = false`, dann das Ziel-Programm auf `true`. Reine Anwendungslogik, keine Persistenz-Constraint. Gleiches Muster wie die bereits bestehende Kraft-/Cardio-Feld-Invariante in `WorkoutEditorViewModel.updateActivityType`, die seit Projektbeginn ebenfalls nur im ViewModel lebt.
3. **Gar nicht durchsetzen** – mehrere Standard-Programme zulassen, UI zeigt einfach das zuletzt gesetzte oder alle. Am einfachsten, aber verletzt die eigentliche Produktanforderung ("dein Standard-Plan" ist als Singular gedacht) und würde die "weiter mit Day N"-Anzeige auf dem Dashboard mehrdeutig machen.

## Entscheidung
Wir setzen die Invariante weiterhin ausschließlich in der ViewModel-Schicht durch (Option 2), zusätzlich abgesichert durch einen `assert` (`WorkoutProgramEditorViewModel.assertAtMostOneDefault`) nach jedem Save-Pfad. Das folgt dem in diesem Projekt etablierten Präzedenzfall (`updateActivityType`) und vermeidet die Mehrkomplexität einer eigens dafür eingeführten Singleton-Struktur.

## Konsequenzen
- Positiv: Konsistent mit bestehendem Muster im Code, kein zusätzliches Modell, geringer Implementierungsaufwand.
- Negativ/Risiken: Jeder Code-Pfad, der ein `WorkoutProgram` anlegt oder `isDefault` setzt, MUSS über `WorkoutProgramEditorViewModel.save()` oder `setDefault(_:in:)`/`setAsDefaultAndSave(_:in:)` laufen – ein direkt konstruiertes `WorkoutProgram(isDefault: true)` (z.B. in einem Test-Fixture) umgeht die Invariante stillschweigend. Der `assert` fängt das nur im Debug-Build ab, nicht im Release-Build.
- Was würde uns zwingen, das zu revidieren? Sollte sich zeigen, dass Standard-Plan-Verletzungen trotz Assert wiederholt in Tests/Produktion auftreten (z.B. weil mehrere Code-Pfade parallel Programme anlegen), wäre das ein Signal, doch auf eine strukturelle Lösung (Option 1) umzustellen.

## Junior-Schutz-Fragen
- 10x mehr Daten? Die Invariante prüft bei jedem Save alle vorhandenen `WorkoutProgram`s (`context.fetch`) – bei realistischen Nutzerzahlen (wenige bis wenige Dutzend Programme) unproblematisch; würde erst bei sehr vielen Programmen (hunderte+) relevant, was für den Anwendungsfall nicht zu erwarten ist.
- Nutzer-Löschung? Lokale Daten, Löschen der App genügt.
- Migration weg? Betrifft nur ViewModel-Logik, kein Schema-Feld – jederzeit durch eine strukturelle Lösung ersetzbar, ohne Datenmigration.
- Löst die einfachste Option (gar nicht durchsetzen) das Problem auch? Technisch ja, aber sie verletzt die Produktanforderung eines eindeutigen Standard-Plans – deshalb bewusst nicht die einfachste, sondern die zweiteinfachste Option gewählt (wie bereits bei ADR 0002 mit demselben Argumentationsmuster).
