import SwiftUI

/// Wraps a template-rendered icon asset so it always inherits the color of
/// the text/control around it, mirroring the source system's `Icon.jsx`
/// (which masks every glyph with `currentColor`).
struct DSIcon: View {
    let name: String
    var size: CGFloat = 16

    var body: some View {
        Image("icon-\(name)")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}
