import SwiftUI

/// Ein nach rechts geneigtes Parallelogramm (30°, "oben rechts vorstehend") -
/// alle vier Ecken sind für sich rundbar; wird ein zusammenhängender Lauf
/// erledigter Sätze als EIN Shape gerendert (siehe `SetProgressBar`), gibt es
/// dadurch gar keine sichtbare innere Kante mehr, ohne dass hier Ecken pro
/// Segment einzeln "scharf geschaltet" werden müssen.
private struct SkewedRoundedRect: Shape {
    var skew: CGFloat
    var cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let bottomLeft = CGPoint(x: rect.minX, y: rect.maxY)
        let bottomRight = CGPoint(x: rect.maxX - skew, y: rect.maxY)
        let topRight = CGPoint(x: rect.maxX, y: rect.minY)
        let topLeft = CGPoint(x: rect.minX + skew, y: rect.minY)
        let corners = [bottomLeft, bottomRight, topRight, topLeft]

        var path = Path()
        for index in corners.indices {
            let previous = corners[(index - 1 + corners.count) % corners.count]
            let corner = corners[index]
            let next = corners[(index + 1) % corners.count]
            let radius = min(cornerRadius, corner.distance(to: previous) / 2, corner.distance(to: next) / 2)
            let entry = corner.moved(towards: previous, by: radius)
            let exit = corner.moved(towards: next, by: radius)
            if index == 0 {
                path.move(to: entry)
            } else {
                path.addLine(to: entry)
            }
            path.addQuadCurve(to: exit, control: corner)
        }
        path.closeSubpath()
        return path
    }
}

private extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        (other.x - x).magnitude + (other.y - y).magnitude == 0 ? 0 : hypot(other.x - x, other.y - y)
    }

    func moved(towards other: CGPoint, by distance: CGFloat) -> CGPoint {
        let length = hypot(other.x - x, other.y - y)
        guard length > 0 else { return self }
        let fraction = min(distance, length) / length
        return CGPoint(x: x + (other.x - x) * fraction, y: y + (other.y - y) * fraction)
    }
}

/// Satz-Fortschrittsleiste (ersetzt die frühere Übungs-Punktereihe): ein
/// gleich breites, geneigtes Parallelogramm-Segment pro Satz, erledigte
/// Sätze grün, offene weiß-transparent. Direkt benachbarte erledigte Sätze
/// verschmelzen zu einem einzigen Shape (kein Spalt, keine innere Kante),
/// weil sie als eine zusammenhängende Gruppe statt einzelner Segmente
/// gerendert werden.
///
/// Hinweis zur Puls-Animation des nächsten offenen Satzes (`repeatForever`):
/// Live Activities werden vom System episodisch neu gerendert, kein echter
/// Dauer-Animationsloop wie in einer normal laufenden App - nur wenige
/// systemeigene Elemente (z.B. `Text(timerInterval:)`) laufen garantiert
/// kontinuierlich weiter. Bestmöglich umgesetzt, aber auf echtem Gerät
/// manuell zu verifizieren, nicht als getestet vorauszusetzen. Der
/// Fertig-Shimmer (`ShimmerOnAppear`) läuft dagegen zuverlässig, weil er an
/// `.onAppear` bei einem echten Content-Update hängt statt an eine Schleife.
struct SetProgressBar: View {
    let completionFlags: [Bool]
    var totalWidth: CGFloat = 112
    var height: CGFloat = 18

    private let gap: CGFloat = 4
    private let cornerRadius: CGFloat = 3
    private let skewDegrees: Double = 30

    private var segmentWidth: CGFloat {
        guard completionFlags.count > 0 else { return 0 }
        let gapsWidth = CGFloat(max(completionFlags.count - 1, 0)) * gap
        return max((totalWidth - gapsWidth) / CGFloat(completionFlags.count), 4)
    }

    private var skew: CGFloat {
        CGFloat(height) * CGFloat(tan(skewDegrees * .pi / 180))
    }

    /// Gruppiert benachbarte erledigte Sätze zu einem gemeinsamen Bereich -
    /// jede Gruppe wird als genau ein `SkewedRoundedRect` gerendert.
    private var groups: [(range: Range<Int>, isCompleted: Bool)] {
        var result: [(range: Range<Int>, isCompleted: Bool)] = []
        var index = 0
        while index < completionFlags.count {
            let isCompleted = completionFlags[index]
            var end = index + 1
            if isCompleted {
                while end < completionFlags.count, completionFlags[end] { end += 1 }
            }
            result.append((range: index..<end, isCompleted: isCompleted))
            index = end
        }
        return result
    }

    private var firstOpenIndex: Int? {
        completionFlags.firstIndex(of: false)
    }

    var body: some View {
        HStack(spacing: gap) {
            ForEach(groups.indices, id: \.self) { groupIndex in
                let group = groups[groupIndex]
                segment(for: group)
                    .frame(width: segmentWidth * CGFloat(group.range.count), height: height)
                    .id(group.range)
                    .transition(
                        .scale(scale: 0.15, anchor: .leading)
                            .combined(with: .opacity)
                            .animation(.easeOut(duration: 0.32))
                    )
            }
        }
        .animation(.easeOut(duration: 0.32), value: completionFlags)
    }

    @ViewBuilder
    private func segment(for group: (range: Range<Int>, isCompleted: Bool)) -> some View {
        let isNextOpen = !group.isCompleted && group.range.lowerBound == firstOpenIndex
        let isLastSet = group.range.upperBound == completionFlags.count

        ZStack {
            SkewedRoundedRect(skew: skew, cornerRadius: cornerRadius)
                .fill(group.isCompleted ? AnyShapeStyle(DSColor.accent) : AnyShapeStyle(Color.white.opacity(0.28)))

            // Offene Segmente brauchen zusätzlich einen Rand - reine
            // Deckkraft allein war auf dunklem Live-Activity-Hintergrund
            // kaum erkennbar (Nutzer-Feedback nach echtem Gerätetest).
            if !group.isCompleted {
                SkewedRoundedRect(skew: skew, cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.4), lineWidth: 0.75)
            }

            if !group.isCompleted && isLastSet {
                SkewedRoundedRect(skew: skew, cornerRadius: cornerRadius)
                    .fill(sweepGradient)
            }

            if group.isCompleted {
                ShimmerOnAppear()
                    .clipShape(SkewedRoundedRect(skew: skew, cornerRadius: cornerRadius))
            }
        }
        .modifier(PulseIfNeeded(isActive: isNextOpen))
    }

    private var sweepGradient: LinearGradient {
        LinearGradient(
            colors: [.clear, .white.opacity(0.35), .clear],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

/// Langsamer Deckkraft-Puls (100% ↔ 45%, 2s) für den nächsten offenen Satz -
/// eigener Modifier statt Inline-State, damit `@State` sauber pro Segment
/// isoliert bleibt (sonst teilen sich alle Segmente denselben Puls-Zustand).
private struct PulseIfNeeded: ViewModifier {
    let isActive: Bool
    @State private var isDimmed = false

    func body(content: Content) -> some View {
        content
            .opacity(isActive && isDimmed ? 0.45 : 1)
            .onAppear {
                guard isActive else { return }
                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                    isDimmed = true
                }
            }
    }
}

/// Einmaliger Glanzlicht-Sweep über ein frisch erledigtes (grünes) Segment -
/// bewusst kein `repeatForever`, sondern an `.onAppear` gekoppelt: eine neue
/// Segment-Gruppe entsteht nur, wenn sich `completionFlags` durch ein
/// echtes `Activity.update()` ändert (siehe `.id(group.range)` in
/// `SetProgressBar`), der Sweep läuft also garantiert genau einmal beim
/// Fertigwerden - anders als die Dauerschleifen oben (Puls/letzter Satz),
/// ist das nicht von der episodischen Live-Activity-Render-Frequenz abhängig.
private struct ShimmerOnAppear: View {
    @State private var progress: CGFloat = -1

    var body: some View {
        GeometryReader { geometry in
            LinearGradient(
                colors: [.clear, .white.opacity(0.55), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geometry.size.width * 0.6)
            .offset(x: progress * geometry.size.width * 1.6)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6)) {
                    progress = 1
                }
            }
        }
    }
}

/// Rechtsbündige Satz-Kurzanzeige unter der Leiste, z.B. `"3/5 Sätze"`.
struct SetProgressCaption: View {
    let completionFlags: [Bool]

    var body: some View {
        Text("\(completionFlags.filter { $0 }.count)/\(completionFlags.count) Sätze")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
    }
}
