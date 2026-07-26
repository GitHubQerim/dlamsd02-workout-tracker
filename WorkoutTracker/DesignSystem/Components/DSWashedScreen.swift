import SwiftUI

/// Shared full-screen scaffold for the two screens that use the header
/// wash: a scrollable, screen-gutter-padded content area over the
/// top-anchored teal gradient. Extracted so StartView and ResultView
/// can't drift apart on the wash height/inset (both used to hard-code
/// the same `ZStack`/`ScrollView` wrapper independently).
///
/// Explicitly fills the whole screen with `surfaceBase` first: when this
/// is used inside a sheet (LexikonView/LexikonDetailView), there's no
/// surrounding view painting that base color the way ContentView's own
/// ZStack does for StartView/ResultView — without it, the system's sheet
/// background shows through below the 220pt wash and creates a visible
/// seam where the two don't quite match.
struct DSWashedScreen<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack(alignment: .top) {
            DSColor.surfaceBase
                .ignoresSafeArea()

            DSColor.headerWash
                .frame(height: 220)
                .ignoresSafeArea(edges: .top)

            ScrollView {
                content
                    .padding(DSSpacing.screenGutter)
            }
        }
    }
}
