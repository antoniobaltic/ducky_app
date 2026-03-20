import SwiftUI

struct FallingLeavesView: View {
    var count: Int = 12
    @State private var leaves: [LeafParticle] = []

    private let leafColors: [Color] = [
        AppTheme.autumnOrange,
        AppTheme.autumnRed,
        AppTheme.autumnGold,
        Color(red: 0.75, green: 0.55, blue: 0.25),
        Color(red: 0.85, green: 0.35, blue: 0.20)
    ]

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                for leaf in leaves {
                    let elapsed = now - leaf.startTime
                    let progress = (elapsed * leaf.speed).truncatingRemainder(dividingBy: 1.0)
                    let y = progress * (size.height + 30) - 15
                    let drift = sin(elapsed * leaf.driftSpeed + leaf.driftPhase) * leaf.driftAmount
                    let x = leaf.xRatio * size.width + drift
                    let rotation = Angle.degrees(elapsed * leaf.rotationSpeed)

                    let opacity = min(progress * 3, 1.0) * min((1.0 - progress) * 3, 1.0) * leaf.opacity
                    context.opacity = opacity

                    context.translateBy(x: x, y: y)
                    context.rotate(by: rotation)

                    // Draw a simple leaf shape
                    let leafPath = Path { p in
                        p.move(to: CGPoint(x: 0, y: -leaf.size / 2))
                        p.addQuadCurve(
                            to: CGPoint(x: 0, y: leaf.size / 2),
                            control: CGPoint(x: leaf.size * 0.6, y: 0)
                        )
                        p.addQuadCurve(
                            to: CGPoint(x: 0, y: -leaf.size / 2),
                            control: CGPoint(x: -leaf.size * 0.6, y: 0)
                        )
                    }
                    context.fill(leafPath, with: .color(leaf.color))

                    context.rotate(by: -rotation)
                    context.translateBy(x: -x, y: -y)
                }
            }
        }
        .onAppear { generateLeaves() }
        .allowsHitTesting(false)
    }

    private func generateLeaves() {
        leaves = (0..<count).map { _ in
            LeafParticle(
                xRatio: .random(in: 0...1),
                size: .random(in: 6...14),
                speed: .random(in: 0.03...0.08),
                opacity: .random(in: 0.4...0.85),
                driftAmount: .random(in: 15...40),
                driftSpeed: .random(in: 0.3...1.0),
                driftPhase: .random(in: 0...(.pi * 2)),
                rotationSpeed: .random(in: 20...80) * (Bool.random() ? 1 : -1),
                color: leafColors.randomElement() ?? AppTheme.autumnOrange,
                startTime: Date.now.timeIntervalSinceReferenceDate - .random(in: 0...20)
            )
        }
    }
}

private struct LeafParticle {
    let xRatio: CGFloat
    let size: CGFloat
    let speed: Double
    let opacity: Double
    let driftAmount: CGFloat
    let driftSpeed: Double
    let driftPhase: Double
    let rotationSpeed: Double
    let color: Color
    let startTime: TimeInterval
}
