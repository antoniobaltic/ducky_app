import SwiftUI

// MARK: - Animated Wave Shape

struct WaveShape: Shape {
    var offset: Angle
    var amplitude: CGFloat
    var frequency: CGFloat

    var animatableData: Double {
        get { offset.degrees }
        set { offset = .degrees(newValue) }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let midY = height * 0.5

        path.move(to: CGPoint(x: 0, y: midY))

        for x in stride(from: 0, through: width, by: 2) {
            let relX = x / width
            let sine = sin(relX * frequency * .pi * 2 + offset.radians)
            let y = midY + amplitude * sine
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()

        return path
    }
}

// MARK: - Multi-Layer Water Wave Background

struct WaterWaveView: View {
    var baseColor: Color = AppTheme.oceanBlue
    var height: CGFloat = 60
    var speed: Double = 1.0

    @State private var phase1: Angle = .zero
    @State private var phase2: Angle = .degrees(120)
    @State private var phase3: Angle = .degrees(240)

    var body: some View {
        ZStack {
            // Back wave (lightest)
            WaveShape(offset: phase3, amplitude: height * 0.15, frequency: 1.2)
                .fill(baseColor.opacity(0.12))

            // Mid wave
            WaveShape(offset: phase2, amplitude: height * 0.2, frequency: 1.5)
                .fill(baseColor.opacity(0.18))

            // Front wave (darkest)
            WaveShape(offset: phase1, amplitude: height * 0.25, frequency: 1.0)
                .fill(baseColor.opacity(0.25))
        }
        .frame(height: height)
        .onAppear {
            withAnimation(.linear(duration: 6 / speed).repeatForever(autoreverses: false)) {
                phase1 = .degrees(360)
            }
            withAnimation(.linear(duration: 8 / speed).repeatForever(autoreverses: false)) {
                phase2 = .degrees(360 + 120)
            }
            withAnimation(.linear(duration: 10 / speed).repeatForever(autoreverses: false)) {
                phase3 = .degrees(360 + 240)
            }
        }
    }
}

// MARK: - Gentle Wave Divider (for section separators)

struct WaveDivider: View {
    var color: Color = AppTheme.oceanBlue
    var height: CGFloat = 30

    @State private var phase: Angle = .zero

    var body: some View {
        WaveShape(offset: phase, amplitude: height * 0.35, frequency: 2.0)
            .fill(color.opacity(0.08))
            .frame(height: height)
            .onAppear {
                withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                    phase = .degrees(360)
                }
            }
    }
}

// MARK: - Floating Bubbles

struct FloatingBubblesView: View {
    var count: Int = 8
    var color: Color = .white

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<count, id: \.self) { i in
                    BubbleView(
                        color: color,
                        containerSize: geo.size,
                        index: i,
                        total: count
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct BubbleView: View {
    let color: Color
    let containerSize: CGSize
    let index: Int
    let total: Int

    @State private var yOffset: CGFloat = 0
    @State private var opacity: Double = 0

    private var size: CGFloat {
        CGFloat.random(in: 4...14)
    }

    private var startX: CGFloat {
        let segment = containerSize.width / CGFloat(total)
        return segment * CGFloat(index) + CGFloat.random(in: 0...segment)
    }

    private var duration: Double {
        Double.random(in: 4...8)
    }

    var body: some View {
        Circle()
            .fill(color.opacity(opacity))
            .frame(width: size, height: size)
            .position(x: startX, y: containerSize.height + 10 + yOffset)
            .blur(radius: 0.5)
            .onAppear {
                let delay = Double.random(in: 0...3)
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    startBubble()
                }
            }
    }

    private func startBubble() {
        withAnimation(.easeIn(duration: 0.5)) {
            opacity = Double.random(in: 0.15...0.4)
        }
        withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: false)) {
            yOffset = -(containerSize.height + 30)
        }
        // Fade out near the top
        DispatchQueue.main.asyncAfter(deadline: .now() + duration * 0.7) {
            withAnimation(.easeOut(duration: duration * 0.3)) {
                opacity = 0
            }
        }
    }
}

// MARK: - Ripple Effect on Tap

struct RippleModifier: ViewModifier {
    @State private var ripple = false
    @State private var ripplePosition: CGPoint = .zero

    func body(content: Content) -> some View {
        content
            .overlay(
                ZStack {
                    if ripple {
                        Circle()
                            .stroke(AppTheme.skyBlue.opacity(0.3), lineWidth: 2)
                            .frame(width: ripple ? 80 : 0, height: ripple ? 80 : 0)
                            .position(ripplePosition)
                            .opacity(ripple ? 0 : 0.6)
                            .animation(.easeOut(duration: 0.6), value: ripple)
                    }
                }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        ripplePosition = value.location
                        ripple = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                            ripple = false
                        }
                    }
            )
    }
}

extension View {
    func rippleOnTap() -> some View { modifier(RippleModifier()) }
}

// MARK: - Water Splash Particles

struct SplashView: View {
    var color: Color = AppTheme.skyBlue
    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { i in
                Circle()
                    .fill(color.opacity(animate ? 0 : 0.5))
                    .frame(width: CGFloat.random(in: 3...8))
                    .offset(
                        x: animate ? CGFloat.random(in: -40...40) : 0,
                        y: animate ? CGFloat.random(in: -50...(-10)) : 0
                    )
                    .scaleEffect(animate ? 0.3 : 1)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animate = true
            }
        }
    }
}

// MARK: - Preview

#Preview("Water Effects") {
    VStack(spacing: 0) {
        ZStack {
            AppTheme.heroGradient
            FloatingBubblesView(count: 10, color: .white)
            VStack {
                Text("Hero Area")
                    .font(.title.bold())
                    .foregroundStyle(.white)
            }
        }
        .frame(height: 300)

        WaterWaveView(baseColor: AppTheme.oceanBlue, height: 50)
            .offset(y: -25)

        WaveDivider()
            .padding(.top, 20)

        Spacer()
    }
    .ignoresSafeArea()
}
