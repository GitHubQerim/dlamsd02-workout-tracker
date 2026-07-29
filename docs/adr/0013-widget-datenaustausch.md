# 0013 – Widget-Datenaustausch: App-Group-Snapshot-Dateien statt geteilter SwiftData-Instanz
Datum: 2026-07-29 | Status: accepted

## Kontext
Phase E, Block 2 führt zwei Home-Screen-Widgets ein ("Nächstes Workout", "Heatmap"). Diese laufen in einem eigenen Extension-Prozess (`WorkoutTrackerWidgetExtension`) und brauchen Daten auch dann, wenn die App selbst nicht läuft — anders als die Live Activity, die nur per `Activity.update` aus der laufenden App gefüttert wird, reicht hier kein reines Timestamp-Passthrough.

## Optionen
1. **Geteilter SwiftData-Zugriff aus der Extension** (App-Group-Container als `ModelConfiguration`-URL, beide Targets öffnen denselben Store) – naheliegend, aber laut ADR 0001 riskant: Multi-Prozess-Zugriff auf denselben SwiftData-Store ist von Apple für diesen Anwendungsfall nicht vorgesehen und kann zu denselben Use-after-free-/Inkonsistenz-Problemen führen, die dort bereits einmal aufgetreten sind – nur diesmal zwischen zwei Prozessen statt zwei Objekten im selben Prozess.
2. **App-Group + kleine, zweckgebundene JSON-Snapshot-Dateien** – die App berechnet die für die Widgets relevanten Werte (aus den ohnehin vorhandenen `WorkoutProgram.nextEntry(in:)`/`ChallengeInsights.heatmapDays(from:)`-Funktionen) und schreibt sie nach jeder relevanten Änderung in den App-Group-Container. Die Extension liest nur diese fertigen Snapshots, nie den SwiftData-Store selbst.

## Entscheidung
Wir wählen **Option 2**. `WidgetSnapshotStore` (geteilte Datei, in beiden Targets kompiliert) kapselt die Container-Pfad-Logik für Lesen und Schreiben; `WidgetSnapshotRefresher` (nur App-Target, braucht SwiftData + WidgetKit) berechnet die Snapshots aus den bestehenden Auswertungsfunktionen und ruft `WidgetCenter.shared.reloadAllTimelines()` nach jedem relevanten Save auf (Session-Ende, HealthKit-Import, App-Start).

## Konsequenzen
- Positiv: Keine Wiederholung des ADR-0001-Risikos in einem neuen, noch fragileren Multi-Prozess-Kontext. Snapshots sind klein, unabhängig testbar (reiner Encode/Decode-Round-Trip), und die Extension bleibt komplett frei von SwiftData/`ModelContainer`-Lebenszyklus-Fragen.
- Negativ/Risiken: Daten in den Widgets können kurzzeitig veraltet sein (nur so aktuell wie der letzte Refresh-Aufruf), kein Live-Sync bei App-externen Datenänderungen (gibt es hier aber ohnehin nicht - keine weitere Schreibquelle als die App selbst).
- Was würde uns zwingen, das zu revidieren? Bräuchten die Widgets künftig größere, sich häufig ändernde Datenmengen (z.B. eine vollständige Session-Historie statt zweier kleiner Aggregate), würde die Snapshot-Datei-Größe/-Schreibfrequenz zum Problem - dann müsste über einen echten Hintergrund-Sync-Mechanismus nachgedacht werden.

## Junior-Schutz-Fragen
- 10x mehr Nutzer/Daten? Einzelnutzer-App, Snapshot-Größe bleibt konstant klein (ein Eintrag "nächstes Workout", ~140 Tage Heatmap-Aggregat) unabhängig von der Gesamt-Session-Historie.
- Nutzer-Löschung (DSGVO)? Snapshots sind reine Ableitungen aus bereits vorhandenen lokalen Daten, keine zusätzliche Datenkopie mit eigenem Löschbedarf - werden beim nächsten Refresh ohnehin überschrieben.
- Migration weg von App-Group-Snapshots? Da die Extension nur die kleinen, eigenen DTOs (`NextWorkoutSnapshot`, `HeatmapSnapshot`) kennt, ließe sich der Transportweg (z.B. auf CloudKit oder Darwin-Notifications umgestellt) ändern, ohne die Widget-Views selbst anzufassen.
- Löst die einfachste Option (geteilter SwiftData-Zugriff) das Problem auch? Nein einfacher nur auf den ersten Blick - das genau begründete Risiko aus ADR 0001 wäre in einem Multi-Prozess-Kontext eher wahrscheinlicher, nicht unwahrscheinlicher.
