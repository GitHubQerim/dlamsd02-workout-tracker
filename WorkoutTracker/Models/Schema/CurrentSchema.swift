/// Zeigt per Typealias auf die jeweils aktuelle Form von Model-Typen, deren
/// Form sich über die Schema-Versionen hinweg geändert hat, damit der Rest
/// der App weiterhin unqualifiziert z.B. `SetLog` schreiben kann. Alle
/// anderen Model-Typen (`Exercise`, `Workout`, ...) sind formgleich zu V1
/// geblieben und bleiben einfache, unqualifizierte Top-Level-Klassen - für
/// sie ist kein Typealias nötig.
typealias SetLog = SchemaV2.SetLog
typealias PlannedExercise = SchemaV3.PlannedExercise
