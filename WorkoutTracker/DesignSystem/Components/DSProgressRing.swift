import SwiftUI

/// Circular score indicator adapted from `components/core/ProgressRing.jsx`.
struct DSProgressRing: View {
    let value: Int
    let max: Int
    var size: CGFloat = 128
    var thickness: CGFloat = 10
    var label: String

    private var progress: Double {
        max > 0 ? Double(value) / Double(max) : 0
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(DSColor.accentTrack, lineWidth: thickness)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(DSColor.accent, style: StrokeStyle(lineWidth: thickness, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(DSMotion.base, value: progress)
            Text(label)
                .font(DSFont.score)
                .foregroundColor(progress >= 1 ? DSColor.accent : DSColor.textSecondary)
        }
        .frame(width: size, height: size)
    }
}
