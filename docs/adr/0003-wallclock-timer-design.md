# 0003 – Wall-Clock-basiertes Timer-Design
Datum: 2026-07-26 | Status: accepted

## Kontext
Der Workout-Session-Flow braucht zwei Timer: Gesamt-Trainingszeit und Pausen-Timer zwischen Sätzen. Die naive Umsetzung wäre ein hochzählender Counter (`Timer.scheduledTimer` erhöht eine Sekunden-Variable). Das Problem: iOS suspendiert Apps im Hintergrund, ein reiner Counter läuft dann nicht weiter oder driftet, sobald die App wieder aktiv wird.

## Optionen
1. **Hochzählender Counter** – Einfach zu schreiben, aber ungenau bei App-Hintergrund/Suspend, driftet bei verpassten Ticks, und liefert kein sauberes Startzeitpunkt-Modell für eine spätere Live Activity.
2. **Wall-Clock-basiert (gewählt)** – Beim Start eines Timers wird nur `startDate: Date` gespeichert. Die verstrichene Zeit wird bei jedem UI-Tick neu berechnet als `elapsed = Date.now - startDate` (bei Pausen: `startDate` entsprechend anpassen/pausierte Dauer separat führen). Die UI aktualisiert sich per Timer/Task, aber die *Quelle der Wahrheit* ist immer ein Zeitstempel, nie ein akkumulierter Zähler.

## Entscheidung
Wir bauen den Timer wall-clock-basiert. Vom `architecture-reviewer` als größter technischer Fallstrick des gesamten Plans benannt: löst Drift, Hintergrund/Suspend-Verhalten und Genauigkeit in einem, und ist zugleich die richtige Vorarbeit für die spätere Live Activity (ActivityKit-State braucht Start-/End-Timestamps, keine Counter).

## Konsequenzen
- Positiv: Korrekt auch nach App-Suspend/Wiederaufnahme; direkte Wiederverwendbarkeit des Zeitmodells für Live Activity (Phase E); keine Drift über lange Sessions.
- Negativ/Risiken: Pausenlogik (Timer anhalten/fortsetzen) braucht etwas mehr Sorgfalt als ein simpler Counter (z.B. `pausedAt`/`totalPausedDuration` mitführen). Nicht bei jedem Sekunden-Tick in SwiftData schreiben – nur bei Satz-Abhaken/Session-Ende persistieren (batched writes), sonst unnötige I/O-Last.
- Revidieren würde uns zwingen: Wenn sich herausstellt, dass Sub-Sekunden-Genauigkeit nötig wäre (nicht der Fall hier) oder Server-seitige Zeitsynchronisation gebraucht würde.

## Junior-Schutz-Fragen
- 10x mehr Nutzer/Daten? Timer-State ist ephemer (ViewModel), nur Start-/End-Zeitpunkte werden persistiert – kein Skalierungsproblem.
- Nutzer-Löschung? Betrifft nur lokale, ephemere Zustände.
- Migration weg? `startDate`/`Date`-basierte Felder sind Standard-Swift-Typen, kein Lock-in.
- Löst die einfachste Option (Counter) das Problem auch? Nein – genau das war der identifizierte Fallstrick; die "langweiligere", aber korrekte Option ist hier wall-clock, nicht der naive Counter.
