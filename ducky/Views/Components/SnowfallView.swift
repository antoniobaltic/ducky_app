import SwiftUI

struct SnowfallView: View {
    var count: Int = 18
    @State private var particles: [SnowParticle] = []
    @State private var tick: Double = 0

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                for p in particles {
                    let elapsed = now - p.startTime
                    let progress = (elapsed * p.speed).truncatingRemainder(dividingBy: 1.0)
                    let y = progress * (size.height + 20) - 10
                    let drift = sin(elapsed * p.driftSpeed + p.driftPhase) * p.driftAmount
                    let x = p.xRatio * size.width + drift

                    let opacity = min(progress * 4, 1.0) * min((1.0 - progress) * 4, 1.0) * p.opacity
                    context.opacity = opacity
                    let rect = CGRect(x: x - p.size / 2, y: y - p.size / 2, width: p.size, height: p.size)
                    context.fill(Circle().path(in: rect), with: .color(.white))
                }
            }
        }
        .onAppear { generateParticles() }
        .allowsHitTesting(false)
    }

    private func generateParticles() {
        particles = (0..<count).map { _ in
            SnowParticle(
                xRatio: .random(in: 0...1),
                size: .random(in: 2...7),
                speed: .random(in: 0.04...0.1),
                opacity: .random(in: 0.3...0.8),
                driftAmount: .random(in: 8...25),
                driftSpeed: .random(in: 0.5...1.5),
                driftPhase: .random(in: 0...(.pi * 2)),
                startTime: Date.now.timeIntervalSinceReferenceDate - .random(in: 0...15)
            )
        }
    }
}

private struct SnowParticle {
    let xRatio: CGFloat
    let size: CGFloat
    let speed: Double
    let opacity: Double
    let driftAmount: CGFloat
    let driftSpeed: Double
    let driftPhase: Double
    let startTime: TimeInterval
}
