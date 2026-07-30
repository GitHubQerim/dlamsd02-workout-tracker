import SwiftUI

/// Color tokens adapted from the "GreenDarkFitness" design system
/// (originally built for a workout tracker, reused here for the quiz).
/// The app commits to a single dark theme regardless of system appearance,
/// matching the source system's near-black-only palette.
enum DSColor {
    // Neutrals
    static let n0 = Color(hex: 0x000000)
    static let n950 = Color(hex: 0x0a0a0a)
    static let n900 = Color(hex: 0x0f0f0f)
    static let n850 = Color(hex: 0x141414)
    static let n800 = Color(hex: 0x181818)
    static let n750 = Color(hex: 0x1c1c1c)
    static let n700 = Color(hex: 0x232323)
    static let n600 = Color(hex: 0x2e2e2e)
    static let n500 = Color(hex: 0x4a4a4a)
    static let n400 = Color(hex: 0x6b6b6b)
    static let n300 = Color(hex: 0x8c8d8d)
    static let n200 = Color(hex: 0xa5a6a6)
    static let n100 = Color(hex: 0xc3c4c4)
    static let n50 = Color(hex: 0xe6e6e6)
    static let nWhite = Color.white

    // Brand green
    static let green500 = Color(hex: 0x2fb19b)
    static let green600 = Color(hex: 0x25907e)
    static let green700 = Color(hex: 0x1d6c5e)
    static let green850 = Color(hex: 0x12413a)
    static let green900 = Color(hex: 0x18594e)

    // Secondary violet — reserved for negative/"incorrect" states only, never a UI accent
    static let violet500 = Color(hex: 0x935be2)

    // Rank-tier colors (Elo/Rang-Gamification, ADR 0014) — scoped ONLY to
    // rank badges/progress rings (RankBadge, RankSectionCard). Do NOT use
    // elsewhere: the one-accent-color principle above still governs the
    // rest of the UI. Deliberately outside the violet family (reserved for
    // negative states, see above). Placeholder tones, not a finished visual
    // design pass — adjust freely during review.
    static let rankBronze = Color(hex: 0xcd7f32)
    static let rankSilver = Color(hex: 0xb8bcc2)
    static let rankGold = Color(hex: 0xe0b23a)
    static let rankPlatin = Color(hex: 0xd7dee0)
    static let rankDiamond = Color(hex: 0x5fd0c9)
    static let rankMaster = Color(hex: 0x3f6fd6)
    static let rankChallenger = Color(hex: 0xe0763a)

    // Semantic surfaces
    static let surfaceBase = n900
    static let surfaceCard = n800
    static let surfaceCard2 = n750
    static let surfaceInset = n850

    // Semantic text
    static let textPrimary = nWhite
    static let textSecondary = n200
    static let textTertiary = n400
    static let textDisabled = n500
    static let textOnInvert = n950

    // Semantic accents
    static let accent = green500
    static let accentTrack = green850

    /// Correct-answer state. Maps to the source system's "metric-up" role.
    static let correct = green500
    /// Incorrect-answer state. Maps to the source system's "metric-down" role —
    /// the system has no red/traffic-light semantics, so violet stands in for red.
    static let incorrect = violet500

    static let borderSubtle = Color.white.opacity(0.06)
    static let borderStrong = Color.white.opacity(0.12)

    /// Ruhezustand-Füllung für inline editierbare Eingabefelder (z.B.
    /// Reps/Gewicht in SetRow). Bewusst ein eigener Token statt Wiederver-
    /// wendung von `borderSubtle`, obwohl der Wert identisch ist - Fill und
    /// Border sind semantisch unterschiedliche Rollen und sollen unabhängig
    /// voneinander änderbar bleiben.
    static let fieldFill = Color.white.opacity(0.06)

    /// Top-anchored teal wash behind screen headers — the system's only gradient.
    /// Two stops (not several intermediate greens) so the fade to black reads
    /// as one smooth, even transition instead of visible banding.
    static let headerWash = LinearGradient(
        colors: [green900, surfaceBase],
        startPoint: .top,
        endPoint: .bottom
    )
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
