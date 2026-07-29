# 0012 – HealthKit-Dedup-/Sync-Strategie
Datum: 2026-07-29 | Status: accepted

## Kontext
Phase E führt einen bidirektionalen HealthKit-Sync ein: Kraft-Sessions gehen App→Health, Cardio-Workouts kommen Health→App (manueller Import, siehe Scope-Entscheidung im Phase-E-Plan). Ohne Dedup-Mechanismus würde ein wiederholter Import dieselben HK-Workouts erneut als App-Sessions anlegen.

## Optionen
1. **Zeitfenster-Heuristik** (z.B. "kein bereits vorhandenes Workout mit Start-/Enddatum innerhalb ±5 Minuten") – funktioniert auch ohne stabile IDs, aber fehleranfällig bei mehreren ähnlichen Workouts am selben Tag, zusätzliche Toleranz-Parameter nötig.
2. **`HKWorkout.uuid` als eindeutiger Schlüssel** – jedes HealthKit-Sample hat eine stabile, eindeutige UUID. Der Import fetcht vor jedem Sync die Menge aller bereits vorhandenen `WorkoutSession.healthKitUUID`s und schließt diese UUIDs aus der Health-Abfrage aus.

## Entscheidung
Wir wählen **ausschließlich `HKWorkout.uuid`** als Dedup-Schlüssel, kein Zeitfenster-Abgleich. `HealthKitImportViewModel.fetchExistingHealthKitUUIDs()` fetcht vor jedem manuellen Sync alle vorhandenen `WorkoutSession.healthKitUUID`-Werte (`FetchDescriptor` mit `healthKitUUID != nil`) und übergibt sie als `excluding:` an `HealthKitServicing.fetchImportableCardioWorkouts(excluding:)`. Zusätzlich werden eigene Kraft-Workouts (`HKWorkoutActivityType.traditionalStrengthTraining`) grundsätzlich von der Importliste ausgeschlossen (zweite Verteidigungslinie, da die App ohnehin nur Kraft schreibt und nur Cardio importiert).

## Konsequenzen
- Positiv: Kein Toleranz-Parameter zu pflegen/testen, robust gegenüber mehreren ähnlichen Workouts am selben Tag, reine Mengen-Differenz ist trivial unit-testbar ohne echten HealthKit-Zugriff.
- Negativ/Risiken: Setzt voraus, dass `healthKitUUID` beim App→Health-Save zuverlässig zurückgeschrieben wird (siehe `finishSession()` in `WorkoutSessionViewModel`) - schlägt der zweite `persist()` nach dem HK-Save fehl, wäre die Session lokal ohne `healthKitUUID`, obwohl in Health ein Sample existiert. Dieses Fenster ist bewusst in Kauf genommen (kein Blocker-Verhalten laut Scope-Entscheidung), führt im Extremfall zu einem doppelten Health-Sample, nicht zu doppelten App-Sessions.
- Was würde uns zwingen, das zu revidieren? Käme ein automatischer Hintergrund-Sync (Background Delivery, aktuell explizit nicht im Scope) dazu, müsste zusätzlich Nebenläufigkeit zwischen manuellem und automatischem Sync-Trigger bedacht werden.

## Junior-Schutz-Fragen
- 10x mehr Nutzer/Daten? Einzelnutzer-App, Dedup-Fetch ist ein einfacher `FetchDescriptor` über die eigenen, lokal kleinen Sessions - keine Skalierungsfrage.
- Nutzer-Löschung (DSGVO)? Keine zusätzliche Pflicht über das bestehende SwiftData-Löschen hinaus - `healthKitUUID` ist nur ein Fremdschlüssel-Feld, keine eigene Datenkopie.
- Migration weg von diesem Dedup-Mechanismus? Rein additiv (ein Feld + eine Mengen-Differenz) - ließe sich um eine Zeitfenster-Heuristik als zusätzliche Sicherheitsebene ergänzen, ohne bestehende Daten zu migrieren.
- Löst die einfachste Option (Zeitfenster) das Problem auch? Nein zuverlässiger/einfacher: `HKWorkout.uuid` ist bereits eindeutig und stabil vorhanden, eine zusätzliche Heuristik wäre unnötige Komplexität für ein bereits exakt lösbares Problem.
