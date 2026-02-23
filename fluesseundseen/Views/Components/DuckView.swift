import SwiftUI

// MARK: - Ducky Mascot

struct DuckView: View {
    let state: DuckState
    var size: CGFloat = 120

    @State private var bobOffset: CGFloat = 0
    @State private var blinkOpacity: Double = 1
    @State private var wingAngle: Double = 0
    @State private var blushOpacity: Double = 0
    @State private var sparkleRotation: Double = 0

    private var scale: CGFloat { size / 120 }

    var body: some View {
        ZStack {
            duckBody
        }
        .frame(width: size, height: size)
        .onAppear { startAnimations() }
        .onChange(of: state) { startAnimations() }
    }

    // MARK: - Body Parts

    private var duckBody: some View {
        ZStack(alignment: .center) {
            // Shadow
            Ellipse()
                .fill(.black.opacity(0.06))
                .frame(width: 72 * scale, height: 16 * scale)
                .offset(y: 48 * scale)
                .blur(radius: 6 * scale)

            // Feet
            HStack(spacing: 10 * scale) {
                Capsule()
                    .fill(state.billColor.opacity(0.8))
                    .frame(width: 14 * scale, height: 6 * scale)
                    .rotationEffect(.degrees(-8))
                Capsule()
                    .fill(state.billColor.opacity(0.8))
                    .frame(width: 14 * scale, height: 6 * scale)
                    .rotationEffect(.degrees(8))
            }
            .offset(y: 44 * scale + bobOffset)

            // Main body
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [state.bodyColor, state.bodyColor.opacity(0.78)],
                        center: .init(x: 0.38, y: 0.32),
                        startRadius: 2,
                        endRadius: 55 * scale
                    )
                )
                .frame(width: 74 * scale, height: 58 * scale)
                .offset(y: 18 * scale + bobOffset)

            // Belly highlight
            Ellipse()
                .fill(.white.opacity(0.18))
                .frame(width: 46 * scale, height: 32 * scale)
                .offset(x: -4 * scale, y: 22 * scale + bobOffset)

            // Wing
            DuckWing(scale: scale, state: state)
                .offset(x: 14 * scale, y: 24 * scale + bobOffset)
                .rotationEffect(.degrees(wingAngle), anchor: .topLeading)

            // Tail
            DuckTail(scale: scale, state: state)
                .offset(x: -32 * scale, y: 8 * scale + bobOffset)

            // Head
            Circle()
                .fill(
                    RadialGradient(
                        colors: [state.bodyColor.opacity(1.0), state.bodyColor.opacity(0.85)],
                        center: .init(x: 0.4, y: 0.35),
                        startRadius: 2,
                        endRadius: 24 * scale
                    )
                )
                .frame(width: 42 * scale, height: 42 * scale)
                .offset(x: 10 * scale, y: -16 * scale + bobOffset)

            // Cheek blush
            if state == .begeistert || state == .zufrieden {
                Circle()
                    .fill(Color.pink.opacity(blushOpacity))
                    .frame(width: 10 * scale, height: 8 * scale)
                    .offset(x: 22 * scale, y: -8 * scale + bobOffset)
                    .blur(radius: 2 * scale)
            }

            // Bill
            DuckBill(state: state, scale: scale)
                .offset(x: 32 * scale, y: -12 * scale + bobOffset)

            // Eye
            DuckEye(state: state, scale: scale, blinkOpacity: blinkOpacity)
                .offset(x: 18 * scale, y: -24 * scale + bobOffset)

            // Hair tuft
            DuckHairTuft(scale: scale, state: state)
                .offset(x: 4 * scale, y: -38 * scale + bobOffset)

            // State decorations
            stateDecoration
        }
        .frame(width: 90 * scale, height: 110 * scale)
    }

    @ViewBuilder
    private var stateDecoration: some View {
        switch state {
        case .begeistert:
            Group {
                SparkleView(size: 14 * scale)
                    .offset(x: 38 * scale, y: -42 * scale + bobOffset)
                    .rotationEffect(.degrees(sparkleRotation))
                SparkleView(size: 10 * scale)
                    .offset(x: -32 * scale, y: -48 * scale + bobOffset)
                    .rotationEffect(.degrees(-sparkleRotation))
                SparkleView(size: 8 * scale)
                    .offset(x: 42 * scale, y: 0 + bobOffset)
                    .rotationEffect(.degrees(sparkleRotation * 0.5))
            }
        case .frierend:
            Group {
                Text("❄️").font(.system(size: 12 * scale))
                    .offset(x: -34 * scale, y: -30 * scale + bobOffset)
                    .opacity(0.8)
                Text("❄️").font(.system(size: 9 * scale))
                    .offset(x: 38 * scale, y: -44 * scale + bobOffset)
                    .opacity(0.6)
                Text("❄️").font(.system(size: 7 * scale))
                    .offset(x: -20 * scale, y: -50 * scale + bobOffset)
                    .opacity(0.5)
            }
        case .warnend:
            Text("⚠️").font(.system(size: 14 * scale))
                .offset(x: 36 * scale, y: -48 * scale + bobOffset)
        case .zoegernd:
            Text("💧").font(.system(size: 10 * scale))
                .offset(x: 36 * scale, y: -38 * scale + bobOffset)
                .opacity(0.7)
        default:
            EmptyView()
        }
    }

    // MARK: - Animations

    private func startAnimations() {
        // Bob
        withAnimation(
            .easeInOut(duration: state == .frierend ? 0.8 : 2.0)
            .repeatForever(autoreverses: true)
        ) {
            bobOffset = state == .frierend ? -5 * scale : -3 * scale
        }

        // Wing flap
        withAnimation(
            .easeInOut(duration: state == .begeistert ? 0.4 : 2.5)
            .repeatForever(autoreverses: true)
        ) {
            wingAngle = state == .begeistert ? -20 : -3
        }

        // Blush
        if state == .begeistert || state == .zufrieden {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                blushOpacity = state == .begeistert ? 0.45 : 0.25
            }
        }

        // Sparkle rotation
        if state == .begeistert {
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                sparkleRotation = 360
            }
        }

        // Blink
        scheduleBlink()
    }

    private func scheduleBlink() {
        let delay = Double.random(in: 2.5...5)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeInOut(duration: 0.06)) { blinkOpacity = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.06)) { blinkOpacity = 1 }
                scheduleBlink()
            }
        }
    }
}

// MARK: - Sparkle

private struct SparkleView: View {
    let size: CGFloat
    @State private var opacity: Double = 0.3

    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: size))
            .foregroundStyle(AppTheme.sunshine)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    opacity = 1.0
                }
            }
    }
}

// MARK: - Hair Tuft

private struct DuckHairTuft: View {
    let scale: CGFloat
    let state: DuckState

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(state.bodyColor.opacity(0.7))
                    .frame(width: 3 * scale, height: 10 * scale)
                    .rotationEffect(.degrees(Double(i - 1) * 18))
                    .offset(x: CGFloat(i - 1) * 3 * scale)
            }
        }
    }
}

// MARK: - Tail

private struct DuckTail: View {
    let scale: CGFloat
    let state: DuckState

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(state.bodyColor.opacity(0.6 - Double(i) * 0.1))
                    .frame(width: 12 * scale, height: 4 * scale)
                    .rotationEffect(.degrees(Double(i - 1) * 15 - 10))
                    .offset(y: CGFloat(i) * 3 * scale)
            }
        }
    }
}

// MARK: - Bill

private struct DuckBill: View {
    let state: DuckState
    let scale: CGFloat

    var body: some View {
        ZStack {
            Capsule()
                .fill(state.billColor)
                .frame(width: 18 * scale, height: 9 * scale)
                .offset(y: -2 * scale)

            Capsule()
                .fill(state.billColor.opacity(0.75))
                .frame(width: 16 * scale, height: 7 * scale)
                .offset(y: 4 * scale)

            mouthShape
        }
    }

    @ViewBuilder
    private var mouthShape: some View {
        switch state {
        case .begeistert:
            Path { p in
                p.move(to: CGPoint(x: 2 * scale, y: 4 * scale))
                p.addQuadCurve(
                    to: CGPoint(x: 14 * scale, y: 4 * scale),
                    control: CGPoint(x: 8 * scale, y: 10 * scale)
                )
            }
            .stroke(Color.white.opacity(0.6), lineWidth: 1.5 * scale)
            .frame(width: 18 * scale, height: 12 * scale)
            .offset(y: 1 * scale)
        case .zufrieden:
            Path { p in
                p.move(to: CGPoint(x: 3 * scale, y: 4 * scale))
                p.addQuadCurve(
                    to: CGPoint(x: 13 * scale, y: 4 * scale),
                    control: CGPoint(x: 8 * scale, y: 7 * scale)
                )
            }
            .stroke(Color.white.opacity(0.5), lineWidth: 1.2 * scale)
            .frame(width: 18 * scale, height: 10 * scale)
            .offset(y: 1 * scale)
        case .frierend, .warnend:
            Path { p in
                p.move(to: CGPoint(x: 3 * scale, y: 6 * scale))
                p.addQuadCurve(
                    to: CGPoint(x: 13 * scale, y: 6 * scale),
                    control: CGPoint(x: 8 * scale, y: 2 * scale)
                )
            }
            .stroke(Color.white.opacity(0.5), lineWidth: 1.2 * scale)
            .frame(width: 18 * scale, height: 10 * scale)
        default:
            EmptyView()
        }
    }
}

// MARK: - Eye

private struct DuckEye: View {
    let state: DuckState
    let scale: CGFloat
    let blinkOpacity: Double

    var body: some View {
        ZStack {
            Ellipse()
                .fill(.white)
                .frame(width: eyeWidth, height: eyeHeight * blinkOpacity + 0.5)
                .opacity(blinkOpacity < 0.2 ? 0 : 1)

            Circle()
                .fill(.black)
                .frame(width: 5 * scale, height: 5 * scale)
                .offset(x: 1 * scale, y: -1 * scale)
                .opacity(blinkOpacity < 0.2 ? 0 : 1)

            Circle()
                .fill(.white.opacity(0.9))
                .frame(width: 2.5 * scale, height: 2.5 * scale)
                .offset(x: 2.5 * scale, y: -2.5 * scale)
                .opacity(blinkOpacity < 0.2 ? 0 : 1)

            if state == .zoegernd {
                Capsule()
                    .fill(.black.opacity(0.7))
                    .frame(width: 10 * scale, height: 2 * scale)
                    .rotationEffect(.degrees(-15))
                    .offset(x: 1 * scale, y: -10 * scale)
                    .opacity(blinkOpacity < 0.2 ? 0 : 1)
            }

            if state == .frierend {
                Capsule()
                    .fill(.black.opacity(0.6))
                    .frame(width: 10 * scale, height: 2.5 * scale)
                    .offset(y: 3 * scale)
            }

            if state == .begeistert {
                Image(systemName: "star.fill")
                    .font(.system(size: 7 * scale))
                    .foregroundStyle(.yellow)
                    .offset(x: 1 * scale, y: -1 * scale)
                    .opacity(blinkOpacity < 0.2 ? 0 : 1)
            }
        }
    }

    private var eyeWidth: CGFloat {
        switch state {
        case .begeistert: return 13 * scale
        case .frierend, .warnend: return 10 * scale
        default: return 11 * scale
        }
    }

    private var eyeHeight: CGFloat {
        switch state {
        case .begeistert: return 13 * scale
        case .frierend: return 6 * scale
        default: return 10 * scale
        }
    }
}

// MARK: - Wing

private struct DuckWing: View {
    let scale: CGFloat
    let state: DuckState

    var body: some View {
        Ellipse()
            .fill(
                LinearGradient(
                    colors: [state.bodyColor.opacity(0.55), state.bodyColor.opacity(0.35)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 26 * scale, height: 16 * scale)
            .rotationEffect(.degrees(20))
    }
}

// MARK: - Pin version for Map

struct DuckPinView: View {
    let state: DuckState
    @State private var appear = false

    var body: some View {
        ZStack {
            Circle()
                .fill(state.bodyColor.opacity(0.25))
                .frame(width: 44, height: 44)
                .scaleEffect(appear ? 1.0 : 0.6)

            Circle()
                .fill(state.bodyColor)
                .frame(width: 36, height: 36)
                .shadow(color: state.bodyColor.opacity(0.4), radius: 6, y: 2)

            DuckView(state: state, size: 28)
                .offset(y: -2)
        }
        .onAppear {
            withAnimation(AppTheme.springAnimation) { appear = true }
        }
    }
}

// MARK: - Small inline badge

struct DuckBadge: View {
    let state: DuckState
    var size: CGFloat = 40

    var body: some View {
        DuckView(state: state, size: size)
    }
}

// MARK: - Preview

#Preview("Ducky States") {
    ScrollView(.horizontal) {
        HStack(spacing: 24) {
            ForEach(DuckState.allCases, id: \.rawValue) { state in
                VStack(spacing: 8) {
                    DuckView(state: state, size: 100)
                    Text(state.title)
                        .font(AppTheme.cardTitle)
                    Text(state.line)
                        .font(AppTheme.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(width: 120)
                }
                .padding()
                .background(state.backgroundGradient, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding()
    }
}
