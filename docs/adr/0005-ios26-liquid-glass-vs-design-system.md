# 0005 – iOS 26 als Deployment-Target + Abgrenzung Liquid Glass vs. eigenes Design-System
Datum: 2026-07-26 | Status: accepted

## Kontext
DLAMSD01 hatte iOS 16.0 als Deployment-Target. Für DLAMSD02 wurde bewusst auf **iOS 26.0** gegangen (aktuelles SDK, Swift-6-Concurrency ohne Workarounds, stabileres SwiftData). Mit iOS 26 kommt Apples neue System-Optik "Liquid Glass" (durchscheinende Materialien für System-Chrome wie Tab-Bars, Navigation-Bars, Sheets). Das eigene Design-System "GreenDarkFitness" (near-black UI, ein Mint-Grün-Akzent) ist bewusst eigenständig gestaltet – ohne klare Grenze würde Liquid Glass unkontrolliert in die App durchsickern und mit dem eigenen Look kollidieren.

## Optionen
1. **Liquid Glass überall zulassen** – Am wenigsten Aufwand, aber verwässert die Design-System-Identität, die im Vorgängerprojekt bewusst aufgebaut wurde (Bewertungskriterium Kreativität).
2. **Design-System überall erzwingen, auch System-Chrome** – Maximale visuelle Konsistenz, aber hoher Aufwand (Custom-Tab-Bar, Custom-Navigation-Bar) für wenig Mehrwert und Reibung mit systemeigenem Verhalten (Safe-Area, Dynamic Island, Akzessibilität).
3. **Klare Grenze (gewählt)** – System-Chrome (TabView-Tab-Bar, NavigationStack-Bars, System-Sheets) darf die native iOS-26-Optik (Liquid Glass) zeigen. Bildschirminhalt (Cards, Buttons, Typografie, Farben, Icons) bleibt vollständig auf dem eigenen Design-System.

## Entscheidung
Wir ziehen die Grenze an der Content-/Chrome-Trennung: `ContentView` nutzt `TabView`/`NavigationStack` unverändert (System-Optik), alle Screen-Inhalte laufen über `DSWashedScreen`, `DSCard`, `DSButton` etc.

## Konsequenzen
- Positiv: Kein Kampf gegen System-Verhalten bei Chrome-Elementen (Safe-Area, Dynamic Type, Akzessibilität funktionieren automatisch korrekt); Design-System-Identität bleibt im eigentlichen Content klar erkennbar und dokumentierbar im Bericht.
- Negativ/Risiken: Sichtbarer Stil-Bruch zwischen Tab-Bar (Liquid Glass, hell/transparent-artig) und Content (near-black) ist bewusst in Kauf genommen – falls das im Bericht kritisiert werden könnte, muss die Begründung (Kreativität vs. Plattform-Konformität) explizit ausformuliert werden.
- Revidieren würde uns zwingen: Wenn die visuelle Inkonsistenz in einem Usability-/Design-Review (Skill `design-review`) als störend bewertet wird, müsste über eine Custom-Tab-Bar nachgedacht werden.

## Junior-Schutz-Fragen
- 10x mehr Nutzer/Daten? Nicht relevant für eine UI-Stilentscheidung.
- Nutzer-Löschung? Nicht relevant.
- Migration weg? Grenze ist rein durch Verwendung von System- vs. Custom-Views gezogen, jederzeit in beide Richtungen verschiebbar (z.B. später doch Custom-Tab-Bar bauen).
- Löst die einfachste Option (überall Liquid Glass) das Problem auch? Funktional ja, aber schwächt das eigene Design-System als Kreativitäts-Beleg – deshalb bewusst die etwas aufwendigere, aber differenziertere Grenzziehung gewählt.
