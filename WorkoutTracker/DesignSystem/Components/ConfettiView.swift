import SwiftUI

/// Kleiner, abhängigkeitsfreier Konfetti-Burst (kein neues Package, "boring
/// technology first") - eine Handvoll animierter Formen mit randomisiertem
/// Offset/Rotation/Farbe, ausgelöst über `trigger`. Bewusst nur für
/// Meilensteine gedacht (Rang-Aufstieg, Streak-Meilensteine), nicht für
/// jeden normalen Elo-Gewinn - siehe `WorkoutCompletionView`.
struct ConfettiView: View {
    @Binding var trigger: Bool
    var pieceCount: Int = 24

    private struct Piece: Identifiable {
        let id = UUID()
        let color: Color
        let xOffset: CGFloat
        let rotation: Double
        let size: CGFloat
    }

    @State private var pieces: [Piece] = []
    @State private var animate = false

    private static let palette: [Color] = [
        DSColor.rankBronze, DSColor.rankSilver, DSColor.rankGold,
        DSColor.rankPlatin, DSColor.rankDiamond, DSColor.rankMaster, DSColor.rankChallenger
    ]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(pieces) { piece in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(piece.color)
                        .frame(width: piece.size, height: piece.size * 0.4)
                        .rotationEffect(.degrees(animate ? piece.rotation : 0))
                        .offset(x: piece.xOffset, y: animate ? proxy.size.height + 40 : -20)
                        .opacity(animate ? 0 : 1)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, newValue in
            guard newValue else { return }
            burst()
        }
    }

    private func burst() {
        pieces = (0..<pieceCount).map { _ in
            Piece(
                color: Self.palette.randomElement() ?? DSColor.accent,
                xOffset: CGFloat.random(in: -140...140),
                rotation: Double.random(in: 180...720),
                size: CGFloat.random(in: 6...12)
            )
        }
        animate = false
        withAnimation(.easeIn(duration: 1.1)) {
            animate = true
        }
        Task {
            try? await Task.sleep(for: .seconds(1.3))
            trigger = false
            animate = false
            pieces = []
        }
    }
}
