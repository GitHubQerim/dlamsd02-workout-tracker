# 0011 – HealthKitService-Architektur: erster echter Service statt zustandsloser Support-Extensions
Datum: 2026-07-29 | Status: accepted

## Kontext
Bisher (Phase A–D) besteht der gesamte App-Code ausschließlich aus zustandslosen `extension WorkoutSession { func ...(in context: ModelContext) }`-Erweiterungen in `WorkoutTracker/Support/` (z.B. `PersonalRecordDetection.swift`, `ChallengeProgressMaterialization.swift`) — keine Protokolle, keine Klassen, kein Service-Layer im gesamten Projekt. Dependency Injection läuft konsequent über `@Environment(\.modelContext)` bzw. per Konstruktor-Parameter an ViewModels.

Für Phase E (bidirektionaler HealthKit-Sync) wird ein `HKHealthStore`-Zugriff benötigt. `HKHealthStore` ist selbst ein Objekt mit echtem Lebenszyklus (Autorisierungsstatus, laufende Queries) – das passt nicht in eine zustandslose Extension-Funktion.

## Optionen
1. **Weiter im bisherigen Stil (freie Funktionen ohne State-Handle)** – bei jedem Aufruf müsste ein neuer `HKHealthStore` instanziiert werden. Funktional möglich, aber unüblich, erschwert Autorisierungsstatus-Caching und wiederholte Query-Verwaltung.
2. **Singleton `HKHealthStore` ohne Protokoll** – einfach, aber keine Testbarkeit: kein echter HealthKit-Zugriff in Unit-Tests/CI möglich, `finishSession()`/Import-Logik ließe sich nicht ohne echtes Gerät/Simulator-Health-Setup testen.
3. **`HealthKitServicing`-Protokoll + reale Implementierung (`HealthKitService`) + Mock (`MockHealthKitService`)**, injiziert per Default-Parameter in `WorkoutSessionViewModel` (analog zum bestehenden `context`-Parameter-Muster) – gewählt.

## Entscheidung
Wir führen `HealthKitServicing` als **genau eine** dokumentierte Ausnahme vom bisherigen "keine Klassen/Protokolle"-Stil ein, kein genereller Strategiewechsel für den Rest der App. Das Protokoll arbeitet ausschließlich mit eigenen DTOs (`HealthKitOutgoingSession`, `HealthKitWorkoutSample`), **nie** mit rohen `HKWorkout`/`HKSample`-Typen und **nie** mit einem `ModelContext`-Parameter. Damit kann das in ADR 0001 dokumentierte Risiko (ein `ModelContext` ohne `ModelContainer`-Referenz in einer async-Closure führt zu einem Use-after-free-artigen Crash) bei den async HealthKit-Callbacks gar nicht erst entstehen: die Rückschreibung nach SwiftData (`session.healthKitUUID = ...`, `context.save()`) passiert immer synchron im ViewModel, nachdem ein `await` zurückkehrt, mit dem ohnehin im Scope gehaltenen `context` – nie in einer Closure, die nur einen isolierten Context einfängt.

## Konsequenzen
- Positiv: Testbarkeit ohne echten HealthKit-Zugriff (`MockHealthKitService`), sauberer Schnitt zwischen App-Fachlichkeit (DTOs) und HealthKit-API-Oberfläche, keine Wiederholung des ADR-0001-Fehlers in einem neuen, async-lastigen Codepfad.
- Negativ/Risiken: Erster Stil-Bruch im Projekt (Protokoll + Klasse statt Extension) – muss im Projektbericht als bewusste, begründete Ausnahme dargestellt werden, nicht als Inkonsistenz. Etwas mehr Boilerplate (Protokoll + zwei Implementierungen) für einen einzigen Anwendungsfall.
- Was würde uns zwingen, das zu revidieren? Käme ein zweiter, ähnlich zustandsbehafteter externer Dienst dazu (z.B. CloudKit-Sync), würde sich die Frage stellen, ob ein generelleres Service-Muster für das ganze Projekt sinnvoller ist als mehrere Einzelfall-Ausnahmen.

## Junior-Schutz-Fragen
- 10x mehr Nutzer/Daten? Einzelnutzer-App, `HealthKitServicing`-Calls sind pro Session/Import einmalig, keine Skalierungsfrage.
- Nutzer-Löschung (DSGVO)? HealthKit-Daten liegen in Apple Health, nicht in der App-Kontrolle; die App schreibt/löscht nur eigene Samples über `healthKitUUID` (siehe ADR 0012), keine zusätzliche Löschpflicht über das ohnehin bestehende SwiftData-Löschen hinaus.
- Migration weg von HealthKit? Da nur eigene DTOs im Protokoll verwendet werden (keine `HK*`-Typen an der Außenkante), ließe sich `HealthKitService` durch eine andere Implementierung ersetzen, ohne Aufrufer (`WorkoutSessionViewModel`, `HealthKitImportViewModel`) anzufassen.
- Löst die einfachste Option (Singleton ohne Protokoll) das Problem auch? Nein – ohne Protokoll wäre `finishSession()`/der Import-Flow nicht ohne echtes HealthKit-Setup testbar, was dem Projekt-Testniveau der bisherigen Phasen widerspricht.
