import SwiftUI
import UIKit

/// Type roles adapted from the "GreenDarkFitness" design system's typography.css.
/// Manrope ships as a single variable-weight font file, so each role resolves
/// its exact weight (400–800) via the font's `wght` variation axis instead of
/// relying on SwiftUI's coarse Font.Weight buckets.
enum DSFont {
    static let screenTitle = manrope(size: 17, weight: 700)
    static let greeting = manrope(size: 20, weight: 700)
    /// Extra role (not in the source dashboard system) for quiz question text —
    /// reuses an existing scale step (17px) at a distinct weight rather than
    /// introducing a new size.
    static let question = manrope(size: 17, weight: 600)
    static let metric = manrope(size: 15, weight: 700)
    static let body = manrope(size: 14, weight: 500)
    static let label = manrope(size: 12, weight: 500)
    static let caption = manrope(size: 11, weight: 500)
    static let micro = manrope(size: 10, weight: 600)
    /// Extra role for the big result-screen score number — reuses the token
    /// scale's unused 34px step rather than inventing a new size.
    static let score = manrope(size: 34, weight: 700)

    private static let wghtAxis: UIFontDescriptor.AttributeName =
        UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String)
    private static let wghtAxisIdentifier = 0x77676874 // OpenType 'wght' tag

    /// Builds a Manrope `Font` at the exact weight axis value and scales it
    /// with the user's Dynamic Type setting (via `UIFontMetrics`), since
    /// wrapping a raw `UIFont` in `Font(_:)` otherwise ignores it.
    static func manrope(size: CGFloat, weight: CGFloat) -> Font {
        let descriptor = UIFontDescriptor(name: "Manrope", size: size)
            .addingAttributes([wghtAxis: [wghtAxisIdentifier: weight]])
        let baseFont = UIFont(descriptor: descriptor, size: size)
        let scaledFont = UIFontMetrics(forTextStyle: .body).scaledFont(for: baseFont)
        return Font(scaledFont)
    }
}
