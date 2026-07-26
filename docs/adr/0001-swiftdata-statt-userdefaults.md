# 0001 – SwiftData statt UserDefaults für Trainingsdaten
Datum: 2026-07-26 | Status: accepted

## Kontext
DLAMSD01 (Fitness-Quiz) hat High-Scores in UserDefaults gespeichert – flach, ein Wert pro Kategorie/Schwierigkeit. DLAMSD02 muss relationale Daten halten: Übungen, Workout-Pläne mit mehreren geplanten Übungen, Workout-Sessions mit mehreren Set-Logs, Challenges mit mehreren Progress-Einträgen. UserDefaults ist für Key-Value-Paare gedacht, nicht für Objektgraphen mit Referenzen.

## Optionen
1. **UserDefaults + manuelles JSON-Encoding** – Kein neues Framework, aber keine echten Relationen, keine Migrationsunterstützung, wachsende Datenmengen (Wochen/Monate an Sessions) werden bei jedem Save komplett neu serialisiert.
2. **Core Data** – Bewährt, aber deutlich mehr Boilerplate (NSManagedObject-Subclasses, .xcdatamodeld-Editor) für ein Kurs-Projekt dieser Größe.
3. **SwiftData** – Deklarative `@Model`-Klassen, native Swift-Typen, direkt aus SwiftUI nutzbar (`@Query`), eingebauter Migrationspfad via `VersionedSchema`. Setzt iOS 17+ voraus (hier ohnehin iOS 26 Ziel).

## Entscheidung
Wir wählen **SwiftData**, weil es für die vorhandenen Relationen (Plan → Übungen → Sessions → Sets → Challenges → Progress-Einträge) die langweiligste passende Option ist – kein Umweg über manuelles JSON-Modeling wie bei UserDefaults, aber auch nicht der Ceremony-Aufwand von Core Data.

## Konsequenzen
- Positiv: Objektgraph bildet die Fachlichkeit direkt ab, `@Query` vereinfacht SwiftUI-Bindung, guter "Transfer"-Beleg gegenüber DLAMSD01 (bewusste Weiterentwicklung der Persistenzstrategie).
- Negativ/Risiken: Neues Framework für dieses Projekt – Lernkurve bei Migrations-Edge-Cases; SwiftData ist jünger als Core Data, weniger Community-Prior-Art bei Nischenproblemen.
- Revidieren würde uns zwingen: harte Performance-Probleme mit sehr großen Session-Historien (unwahrscheinlich im Kurs-Rahmen) oder ein Deployment-Target-Downgrade unter iOS 17.

## Junior-Schutz-Fragen
- 10x mehr Nutzer/Daten? Einzelnutzer-App (kein Server-Sync), Datenmenge bleibt pro Gerät klein (Monate an Trainingsdaten, keine Multi-User-Last) – muss das nicht aushalten.
- Nutzer-Löschung (DSGVO)? Rein lokale Daten, kein Server – Löschen der App/des lokalen Stores genügt, kein Extra-Mechanismus nötig.
- Migration weg von SwiftData? Datenmodell ist von Anfang an in eigenen Swift-Structs/Enums gedacht (ActivityType etc.), `@Model`-Klassen sind dünne Wrapper – Export nach Core Data oder eigenem Format wäre machbar, kein Hard-Lock-in auf Apple-spezifisches Format jenseits des Speicherorts.
- Löst die einfachste Option (UserDefaults) das Problem auch? Nein – sobald Relationen (Session → mehrere Sets, Challenge → mehrere Progress-Einträge) dazukommen, wird UserDefaults schnell zu selbstgebautem ORM-Ersatz; SwiftData ist hier die langweiligere, nicht die exotischere Wahl.
