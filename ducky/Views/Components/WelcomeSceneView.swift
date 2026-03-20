import SwiftUI

// MARK: - Welcome Scene Background

/// A joyful summer lake scene for the onboarding welcome page.
/// Sky with sun, birds, and clouds above; animated water with fish below.
struct WelcomeSceneView: View {
    @State private var sunPulse = false
    @State private var rayRotation: Double = 0
    @State private var cloud1X: CGFloat = -0.15
    @State private var cloud2X: CGFloat = 0.6

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let horizon = h * 0.58

            ZStack {
                // 1. Sky gradient
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.95, blue: 0.78),   // warm sunshine top
                        Color(red: 1.0, green: 0.90, blue: 0.80),   // soft peach
                        Color(red: 0.78, green: 0.90, blue: 1.0),   // sky blue at horizon
                    ],
                    startPoint: .top,
                    endPoint: UnitPoint(x: 0.5, y: 0.58)
                )
                .ignoresSafeArea()

                // 2. Water fill below horizon
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: horizon)
                    LinearGradient(
                        colors: [
                            AppTheme.skyBlue.opacity(0.30),
                            AppTheme.oceanBlue.opacity(0.18),
                            AppTheme.oceanBlue.opacity(0.12)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .ignoresSafeArea()

                // 3. Sun with glow
                sunView
                    .position(x: w * 0.78, y: h * 0.10)
                    .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: sunPulse)

                // 4. Sun rays
                sunRays
                    .position(x: w * 0.78, y: h * 0.10)
                    .animation(.linear(duration: 40).repeatForever(autoreverses: false), value: rayRotation)

                // 5. Clouds
                cloudShape(width: w * 0.35, height: 30)
                    .position(x: cloud1X * w, y: h * 0.16)
                    .animation(.linear(duration: 50).repeatForever(autoreverses: false), value: cloud1X)

                cloudShape(width: w * 0.28, height: 24)
                    .position(x: cloud2X * w, y: h * 0.28)
                    .animation(.linear(duration: 65).repeatForever(autoreverses: false), value: cloud2X)

                cloudShape(width: w * 0.22, height: 18)
                    .position(x: (cloud1X + 0.45) * w, y: h * 0.22)
                    .animation(.linear(duration: 50).repeatForever(autoreverses: false), value: cloud1X)

                // 6. Birds
                BirdsView(skyWidth: w, skyHeight: horizon)
                    .position(x: w / 2, y: horizon / 2)

                // 7. Water wave at horizon
                WaterWaveView(baseColor: AppTheme.oceanBlue, height: 40, speed: 0.7)
                    .opacity(0.35)
                    .position(x: w / 2, y: horizon + 10)

                // 8. Fish in the water
                FishView(waterWidth: w, waterHeight: h - horizon)
                    .position(x: w / 2, y: horizon + (h - horizon) / 2)

                // 9. Water sparkles
                SparklesView(areaWidth: w, areaHeight: (h - horizon) * 0.4)
                    .position(x: w / 2, y: horizon + (h - horizon) * 0.2)
            }
        }
        .onAppear {
            sunPulse = true
            rayRotation = 360
            cloud1X = 1.15
            cloud2X = 1.20
        }
        .allowsHitTesting(false)
    }

    // MARK: - Sun

    private var sunView: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            AppTheme.sunshine.opacity(0.45),
                            AppTheme.sunshine.opacity(0.15),
                            AppTheme.sunshine.opacity(0.0)
                        ],
                        center: .center,
                        startRadius: 30,
                        endRadius: 100
                    )
                )
                .frame(width: 200, height: 200)
            // Bright core
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.85),
                            AppTheme.sunshine.opacity(0.60),
                            AppTheme.sunshine.opacity(0.0)
                        ],
                        center: .center,
                        startRadius: 5,
                        endRadius: 40
                    )
                )
                .frame(width: 80, height: 80)
        }
        .scaleEffect(sunPulse ? 1.12 : 0.94)
    }

    // MARK: - Sun Rays

    private var sunRays: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                Capsule()
                    .fill(.white.opacity(0.15))
                    .frame(width: 2.5, height: 70)
                    .offset(y: -60)
                    .rotationEffect(.degrees(Double(i) * 45 + rayRotation))
            }
        }
        .frame(width: 200, height: 200)
    }

    // MARK: - Cloud

    private func cloudShape(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Ellipse()
                .fill(.white.opacity(0.75))
                .frame(width: width, height: height)
                .blur(radius: 8)
            Ellipse()
                .fill(.white.opacity(0.50))
                .frame(width: width * 0.7, height: height * 0.7)
                .offset(x: width * 0.1, y: -height * 0.15)
                .blur(radius: 5)
        }
    }
}

// MARK: - Birds (SwiftUI Shape-based)

struct BirdShape: Shape {
    var flapAngle: Double

    var animatableData: Double {
        get { flapAngle }
        set { flapAngle = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midX = rect.midX
        let midY = rect.midY
        let half = rect.width / 2
        let tipY = midY - half * 0.35 * (1 + flapAngle)

        // Left wing
        path.move(to: CGPoint(x: midX - half, y: tipY))
        path.addQuadCurve(
            to: CGPoint(x: midX, y: midY),
            control: CGPoint(x: midX - half * 0.4, y: midY - half * 0.15)
        )
        // Right wing
        path.addQuadCurve(
            to: CGPoint(x: midX + half, y: tipY),
            control: CGPoint(x: midX + half * 0.4, y: midY - half * 0.15)
        )
        return path
    }
}

struct BirdData: Identifiable {
    let id = UUID()
    let yRatio: CGFloat
    let wingSpan: CGFloat
    let speed: Double
    let opacity: Double
    let flapSpeed: Double
    let phase: Double
    let startOffset: Double
}

struct BirdsView: View {
    let skyWidth: CGFloat
    let skyHeight: CGFloat
    @State private var birds: [BirdData] = []

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(birds) { bird in
                    let elapsed = now - bird.startOffset
                    let progress = (elapsed * bird.speed).truncatingRemainder(dividingBy: 1.0)
                    let x = progress * (skyWidth + 60) - 30 - skyWidth / 2
                    let bobY = sin(elapsed * 1.5 + bird.phase) * 4
                    let y = bird.yRatio * skyHeight + bobY - skyHeight / 2
                    let flap = sin(elapsed * bird.flapSpeed) * 0.3

                    BirdShape(flapAngle: flap)
                        .stroke(
                            Color(red: 0.30, green: 0.35, blue: 0.50).opacity(0.85),
                            lineWidth: 2.0
                        )
                        .frame(width: bird.wingSpan, height: bird.wingSpan * 0.5)
                        .opacity(bird.opacity)
                        .offset(x: x, y: y)
                }
            }
            .frame(width: skyWidth, height: skyHeight)
        }
        .onAppear { generateBirds() }
    }

    private func generateBirds() {
        let now = Date.now.timeIntervalSinceReferenceDate
        birds = (0..<5).map { _ in
            BirdData(
                yRatio: .random(in: 0.10...0.55),
                wingSpan: .random(in: 22...36),
                speed: .random(in: 0.025...0.045),
                opacity: .random(in: 0.55...0.85),
                flapSpeed: .random(in: 3.0...5.0),
                phase: .random(in: 0...(.pi * 2)),
                startOffset: now - .random(in: 0...25)
            )
        }
    }
}

// MARK: - Fish with Bubbles

struct FishShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let midY = rect.midY

        // Body (oval)
        path.addEllipse(in: CGRect(x: w * 0.15, y: h * 0.2, width: w * 0.55, height: h * 0.6))

        // Tail
        path.move(to: CGPoint(x: w * 0.15, y: midY))
        path.addLine(to: CGPoint(x: 0, y: h * 0.15))
        path.addQuadCurve(
            to: CGPoint(x: 0, y: h * 0.85),
            control: CGPoint(x: w * 0.1, y: midY)
        )
        path.addLine(to: CGPoint(x: w * 0.15, y: midY))

        return path
    }
}

struct FishData: Identifiable {
    let id = UUID()
    let yRatio: CGFloat
    let size: CGFloat
    let speed: Double
    let startOffset: Double
    let bobPhase: Double
    let color: Color
    let goesRight: Bool
}

struct BubbleData: Identifiable {
    let id = UUID()
    let fishIndex: Int
    let xOffset: CGFloat
    let size: CGFloat
    let riseSpeed: Double
    let phase: Double
}

struct FishView: View {
    let waterWidth: CGFloat
    let waterHeight: CGFloat
    @State private var fish: [FishData] = []
    @State private var bubbles: [BubbleData] = []

    var body: some View {
        TimelineView(.animation) { timeline in
            fishContent(now: timeline.date.timeIntervalSinceReferenceDate)
        }
        .onAppear { generateFish() }
    }

    private func fishContent(now: TimeInterval) -> some View {
        ZStack {
            ForEach(bubbles) { bubble in
                bubbleView(bubble: bubble, now: now)
            }
            ForEach(fish) { f in
                singleFishView(f: f, now: now)
            }
        }
        .frame(width: waterWidth, height: waterHeight)
    }

    private func fishX(f: FishData, progress: Double) -> CGFloat {
        if f.goesRight {
            return progress * (waterWidth + 80) - 40 - waterWidth / 2
        } else {
            return (1 - progress) * (waterWidth + 80) - 40 - waterWidth / 2
        }
    }

    @ViewBuilder
    private func bubbleView(bubble: BubbleData, now: TimeInterval) -> some View {
        if bubble.fishIndex < fish.count {
            let f = fish[bubble.fishIndex]
            let elapsed = now - f.startOffset
            let progress = (elapsed * f.speed).truncatingRemainder(dividingBy: 1.0)
            let fX = fishX(f: f, progress: progress)
            let fY = f.yRatio * waterHeight - waterHeight / 2 + sin(elapsed * 1.2 + f.bobPhase) * 5
            let bubbleElapsed = (elapsed * bubble.riseSpeed + bubble.phase).truncatingRemainder(dividingBy: 1.0)

            Circle()
                .fill(.white.opacity(0.4 * (1 - bubbleElapsed)))
                .frame(width: bubble.size, height: bubble.size)
                .offset(
                    x: fX + bubble.xOffset + sin(elapsed * 2 + bubble.phase) * 3,
                    y: fY - bubbleElapsed * 40
                )
        }
    }

    private func singleFishView(f: FishData, now: TimeInterval) -> some View {
        let elapsed = now - f.startOffset
        let progress = (elapsed * f.speed).truncatingRemainder(dividingBy: 1.0)
        let x = fishX(f: f, progress: progress)
        let bobY = sin(elapsed * 1.2 + f.bobPhase) * 5
        let y = f.yRatio * waterHeight - waterHeight / 2 + bobY

        return FishShape()
            .fill(f.color)
            .frame(width: f.size, height: f.size * 0.5)
            .scaleEffect(x: f.goesRight ? 1 : -1, y: 1)
            .rotationEffect(.degrees(sin(elapsed * 3) * 3))
            .opacity(0.6)
            .offset(x: x, y: y)
    }

    private func generateFish() {
        let now = Date.now.timeIntervalSinceReferenceDate
        let fishColors: [Color] = [
            Color(red: 1.0, green: 0.6, blue: 0.3),  // orange
            Color(red: 0.5, green: 0.75, blue: 0.9),  // blue
            Color(red: 0.9, green: 0.5, blue: 0.6),   // pink
            Color(red: 0.6, green: 0.85, blue: 0.5),   // green
        ]
        fish = (0..<4).map { i in
            FishData(
                yRatio: .random(in: 0.15...0.75),
                size: .random(in: 20...32),
                speed: .random(in: 0.02...0.04),
                startOffset: now - .random(in: 0...30),
                bobPhase: .random(in: 0...(.pi * 2)),
                color: fishColors[i % fishColors.count],
                goesRight: Bool.random()
            )
        }

        // 2 bubbles per fish
        bubbles = fish.indices.flatMap { i in
            (0..<2).map { _ in
                BubbleData(
                    fishIndex: i,
                    xOffset: .random(in: -3...5),
                    size: .random(in: 3...6),
                    riseSpeed: .random(in: 0.3...0.6),
                    phase: .random(in: 0...1)
                )
            }
        }
    }
}

// MARK: - Water Sparkles (SwiftUI-based)

private struct SparkleData: Identifiable {
    let id = UUID()
    let xRatio: CGFloat
    let yRatio: CGFloat
    let size: CGFloat
    let maxOpacity: Double
    let blinkSpeed: Double
    let phase: Double
}

private struct SparklesView: View {
    let areaWidth: CGFloat
    let areaHeight: CGFloat
    @State private var sparkles: [SparkleData] = []

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(sparkles) { s in
                    let shimmer = (sin(now * s.blinkSpeed + s.phase) + 1) / 2
                    let x = s.xRatio * areaWidth - areaWidth / 2
                    let y = s.yRatio * areaHeight - areaHeight / 2

                    Circle()
                        .fill(.white)
                        .frame(width: s.size, height: s.size)
                        .opacity(shimmer * s.maxOpacity)
                        .offset(x: x, y: y)
                }
            }
            .frame(width: areaWidth, height: areaHeight)
        }
        .onAppear { generateSparkles() }
    }

    private func generateSparkles() {
        sparkles = (0..<10).map { _ in
            SparkleData(
                xRatio: .random(in: 0.05...0.95),
                yRatio: .random(in: 0.0...1.0),
                size: .random(in: 3...7),
                maxOpacity: .random(in: 0.40...0.75),
                blinkSpeed: .random(in: 2.0...4.5),
                phase: .random(in: 0...(.pi * 2))
            )
        }
    }
}

// MARK: - Preview

#Preview {
    WelcomeSceneView()
}
