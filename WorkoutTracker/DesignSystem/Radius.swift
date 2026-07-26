import CoreGraphics

/// Corner-radius scale adapted from tokens/radius.css, trimmed to the
/// semantic aliases this app actually draws (no sheet/modal in a quiz flow).
enum DSRadius {
    static let chip: CGFloat = 10
    static let tile: CGFloat = 12
    static let card: CGFloat = 14
    static let pill: CGFloat = 999
}
