# 0004 – MVVM statt TCA (Bestätigung trotz größerem Scope)
Datum: 2026-07-26 | Status: accepted

## Kontext
Der globale Stack-Default (CLAUDE.md) für iOS-Projekte ist Swift + The Composable Architecture (TCA). DLAMSD01 ist bewusst davon abgewichen (einfaches SwiftUI+MVVM), mit der Begründung, der Prüfungsleitfaden verlange kein bestimmtes Architektur-Pattern, sondern übersichtlichen, verständlichen Code nach Swift-API-Design-Guidelines – TCA wäre für die Kursgröße Overkill gewesen. DLAMSD02 hat deutlich mehr Scope: SwiftData-Persistenz, Timer-State während einer laufenden Session, später HealthKit-Sync und Live Activity. Frage: Kippt der größere Scope diese Abwägung?

## Optionen
1. **TCA** – Einheitliches State-Management über Reducer/Effects, gut für komplexe, verschachtelte Nebenwirkungen (Timer, HealthKit-Calls, Persistenz). Kosten: signifikanter Boilerplate- und Lernaufwand, der im Projektbericht als reine Pattern-Vorsicht ("weil es die Vorgabe ist"), nicht als fachliche Notwendigkeit begründet werden müsste.
2. **MVVM (gewählt)** – Ein `ObservableObject`/`@Observable`-ViewModel pro fachlichem Bereich (z.B. `WorkoutSessionViewModel` als Single Source of Truth für eine laufende Session), `@Published private(set)`-State mit expliziten Mutator-Methoden – das gleiche Muster wie in DLAMSD01, nur mit mehr fachlichen ViewModels.

## Entscheidung
Wir bleiben bei MVVM. Vom `architecture-reviewer` geprüft und bestätigt: Timer-State und SwiftData sind mit diszipliniertem MVVM gut beherrschbar; TCA hier einzuführen wäre Overengineering aus Vorsicht, nicht aus echtem Bedarf – genau das Muster, das die Architektur-Leitplanken (YAGNI) vermeiden sollen.

## Konsequenzen
- Positiv: Konsistent mit DLAMSD01 (Kontinuität im Projektbericht-Narrativ), geringere Lernkurve, mehr Zeit für die fachlichen Features (Multi-Sport-Modell, Challenges, Auswertungen).
- Negativ/Risiken: Bei mehreren gleichzeitig aktiven, interagierenden ViewModels (z.B. Session-Timer + Challenge-Progress-Update bei Session-Ende) muss Datenfluss diszipliniert bleiben (ein ViewModel = eine klare Verantwortlichkeit), sonst drohen die klassischen MVVM-Probleme (verteilte Business-Logik, unklare Owner-Views).
- Revidieren würde uns zwingen: Wenn sich weitere, tief verschachtelte asynchrone Effekt-Ketten (z.B. HealthKit-Import mit Konfliktauflösung, siehe ADR künftig) als mit MVVM nicht mehr sauber beherrschbar erweisen.

## Junior-Schutz-Fragen
- 10x mehr Nutzer/Daten? Architektur-Pattern-Wahl ist unabhängig von Datenmenge – betrifft Code-Struktur, nicht Skalierung.
- Nutzer-Löschung? Nicht relevant für diese Entscheidung.
- Migration weg? Ein Wechsel zu TCA wäre auch später noch möglich (ViewModels ließen sich schrittweise zu Reducern migrieren), aber nicht der Plan.
- Löst die einfachste Option (MVVM, wie bisher) das Problem auch? Ja – vom architecture-reviewer explizit bestätigt für diesen Scope.
