import SwiftUI

/// Surface adapted from `components/core/Card.jsx`: flat fill, no shadow —
/// depth in this system comes from a stepped surface value, not elevation.
/// The source component also has an "inset" tone for nested containers;
/// this app never nests cards, so it's trimmed to the one tone it uses.
/// An optional border is exposed for the quiz screen's selected/correct/
/// incorrect answer highlight, reusing this shape instead of redeclaring it.
struct DSCard<Content: View>: View {
    var padding: CGFloat = DSSpacing.s12
    /// Set to make same-row cards match height (e.g. the dashboard's
    /// Lexikon/about tiles) — applied before the background so the fill
    /// actually reaches that height instead of being centered inside it.
    var minHeight: CGFloat? = nil
    var background: Color = DSColor.surfaceCard
    var borderColor: Color = .clear
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous)
                    .stroke(borderColor, lineWidth: 1.5)
            )
    }
}
