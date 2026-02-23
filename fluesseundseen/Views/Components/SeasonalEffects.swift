import SwiftUI

// MARK: - Snowfall (Winter: Dec, Jan, Feb)

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

// MARK: - Falling Leaves (Autumn: Sep, Oct, Nov)

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

// MARK: - Spring Blossoms (Mar, Apr, May)

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

// MARK: - Seasonal Overlay (auto-selects the right effect)

struct SeasonalOverlay: View {
    var season: Season = .current

    var body: some View {
        switch season {
        case .winter:
            SnowfallView()
        case .spring:
            SpringBlossomView()
        case .summer:
            FloatingBubblesView(count: 6, color: .white.opacity(0.3))
        case .autumn:
            FallingLeavesView()
        }
    }
}

// MARK: - Preview

#Preview("Seasonal Effects") {
    VStack(spacing: 0) {
        ForEach(Season.allCases, id: \.rawValue) { season in
            ZStack {
                season.heroGradient
                SeasonalOverlay(season: season)
                Text(season.rawValue.capitalized)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }
            .frame(height: 180)
        }
    }
    .ignoresSafeArea()
}
