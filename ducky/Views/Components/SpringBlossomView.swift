import SwiftUI

struct SpringBlossomView: View {
    var count: Int = 10
    @State private var petals: [PetalParticle] = []

    private let petalColors: [Color] = [
        Color(red: 1.0, green: 0.85, blue: 0.90),
        Color(red: 0.95, green: 0.78, blue: 0.85),
        .white,
        Color(red: 1.0, green: 0.90, blue: 0.92),
        Color(red: 0.90, green: 0.82, blue: 0.88)
    ]

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                for petal in petals {
                    let elapsed = now - petal.startTime
                    let progress = (elapsed * petal.speed).truncatingRemainder(dividingBy: 1.0)
                    let y = progress * (size.height + 20) - 10
                    let drift = sin(elapsed * petal.driftSpeed + petal.driftPhase) * petal.driftAmount
                    let x = petal.xRatio * size.width + drift
                    let rotation = Angle.degrees(elapsed * petal.rotationSpeed)

                    let opacity = min(progress * 3, 1.0) * min((1.0 - progress) * 3, 1.0) * petal.opacity
                    context.opacity = opacity

                    context.translateBy(x: x, y: y)
                    context.rotate(by: rotation)

                    let rect = CGRect(x: -petal.size / 2, y: -petal.size * 0.3, width: petal.size, height: petal.size * 0.6)
                    context.fill(Ellipse().path(in: rect), with: .color(petal.color))

                    context.rotate(by: -rotation)
                    context.translateBy(x: -x, y: -y)
                }
            }
        }
        .onAppear { generatePetals() }
        .allowsHitTesting(false)
    }

    private func generatePetals() {
        petals = (0..<count).map { _ in
            PetalParticle(
                xRatio: .random(in: 0...1),
                size: .random(in: 4...10),
                speed: .random(in: 0.025...0.06),
                opacity: .random(in: 0.3...0.7),
                driftAmount: .random(in: 12...30),
                driftSpeed: .random(in: 0.4...1.0),
                driftPhase: .random(in: 0...(.pi * 2)),
                rotationSpeed: .random(in: 15...50) * (Bool.random() ? 1 : -1),
                color: petalColors.randomElement() ?? .white,
                startTime: Date.now.timeIntervalSinceReferenceDate - .random(in: 0...18)
            )
        }
    }
}

private struct PetalParticle {
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
