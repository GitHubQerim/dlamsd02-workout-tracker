import CoreGraphics

/// Spacing scale adapted from tokens/spacing.css. Only the steps actually
/// used by this app are kept (e.g. no tab-bar height — this app has none).
enum DSSpacing {
    static let s4: CGFloat = 4
    static let s8: CGFloat = 8
    static let s12: CGFloat = 12
    static let s16: CGFloat = 16
    static let s20: CGFloat = 20
    static let s24: CGFloat = 24
    static let s32: CGFloat = 32

    /// Screen edge padding.
    static let screenGutter: CGFloat = 14
    /// Gap between sibling cards/tiles.
    static let cardGap: CGFloat = 8
    /// Gap between stacked elements within a card.
    static let stackGap: CGFloat = 10
    /// Gap between larger screen sections.
    static let sectionGap: CGFloat = 16
    /// Minimum tappable control height (HIG/accessibility minimum).
    static let tapMin: CGFloat = 44
}
