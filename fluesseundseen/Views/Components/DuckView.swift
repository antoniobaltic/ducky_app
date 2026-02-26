import SwiftUI

// MARK: - Ducky Mascot (cute rubber duck style)

struct DuckView: View {
    let state: DuckState
    var size: CGFloat = 120

    @State private var bobOffset: CGFloat = 0
    @State private var blinkScale: CGFloat = 1
    @State private var wingAngle: Double = 0
    @State private var blushOpacity: Double = 0
    @State private var sparkleOpacity: Double = 0
    @State private var blinkTask: Task<Void, Never>?

    private var s: CGFloat { size / 120 }

    var body: some View {
        ZStack {
            // Water ripple under duck
            waterRipple

            // Duck
            duckBody
        }
        .frame(width: size, height: size)
        .onAppear { startAnimations() }
        .onChange(of: state) { startAnimations() }
        .onDisappear { blinkTask?.cancel() }
    }

    // MARK: - Water ripple beneath

    private var waterRipple: some View {
        ZStack {
            Ellipse()
                .fill(state.accentColor.opacity(0.06))
                .frame(width: 80 * s, height: 16 * s)
                .offset(y: 44 * s + bobOffset)
                .blur(radius: 4 * s)
            Ellipse()
                .fill(state.accentColor.opacity(0.04))
                .frame(width: 100 * s, height: 12 * s)
                .offset(y: 47 * s + bobOffset)
                .blur(radius: 6 * s)
        }
    }

    // MARK: - Duck body

    private var duckBody: some View {
        ZStack {
            // Body (big round oval - rubber duck style)
            Ellipse()
                .fill(
                    EllipticalGradient(
                        colors: [
                            state.bodyColor,
                            state.bodyColor.opacity(0.85),
                            state.bodyColor.opacity(0.7)
                        ],
                        center: .init(x: 0.4, y: 0.3),
                        startRadiusFraction: 0.0,
                        endRadiusFraction: 0.7
                    )
                )
                .frame(width: 70 * s, height: 52 * s)
                .offset(y: 20 * s + bobOffset)

            // Belly shine
            Ellipse()
                .fill(.white.opacity(0.22))
                .frame(width: 38 * s, height: 26 * s)
                .offset(x: -6 * s, y: 24 * s + bobOffset)
                .blur(radius: 2 * s)

            // Wing
            wing
                .offset(x: 18 * s, y: 24 * s + bobOffset)
                .rotationEffect(.degrees(wingAngle), anchor: .leading)

            // Tail feathers
            tail
                .offset(x: -32 * s, y: 10 * s + bobOffset)

            // Head (big circle - bigger than body for cuteness)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [state.bodyColor, state.bodyColor.opacity(0.88)],
                        center: .init(x: 0.42, y: 0.35),
                        startRadius: 0,
                        endRadius: 26 * s
                    )
                )
                .frame(width: 48 * s, height: 48 * s)
                .offset(x: 4 * s, y: -12 * s + bobOffset)

            // Head shine
            Ellipse()
                .fill(.white.opacity(0.2))
                .frame(width: 18 * s, height: 12 * s)
                .rotationEffect(.degrees(-20))
                .offset(x: -6 * s, y: -24 * s + bobOffset)
                .blur(radius: 2 * s)

            // Cheek blush
            if state == .begeistert || state == .zufrieden {
                Circle()
                    .fill(Color.pink.opacity(blushOpacity))
                    .frame(width: 12 * s, height: 8 * s)
                    .offset(x: 20 * s, y: -4 * s + bobOffset)
                    .blur(radius: 3 * s)
            }

            // Bill (orange beak)
            bill
                .offset(x: 28 * s, y: -8 * s + bobOffset)

            // Eyes (big kawaii style)
            eyeGroup
                .offset(x: 8 * s, y: -18 * s + bobOffset)

            // Crown / hair tuft
            hairTuft
                .offset(x: 0, y: -38 * s + bobOffset)

            // State decorations
            decorations
        }
    }

    // MARK: - Bill

    private var bill: some View {
        ZStack {
            // Upper beak
            RoundedRectangle(cornerRadius: 6 * s)
                .fill(state.billColor)
                .frame(width: 20 * s, height: 10 * s)
                .offset(y: -2 * s)

            // Lower beak (smaller)
            RoundedRectangle(cornerRadius: 4 * s)
                .fill(state.billColor.opacity(0.8))
                .frame(width: 17 * s, height: 7 * s)
                .offset(y: 5 * s)

            // Smile line
            if state == .begeistert || state == .zufrieden {
                Path { p in
                    p.move(to: CGPoint(x: 2 * s, y: 4 * s))
                    p.addQuadCurve(
                        to: CGPoint(x: 16 * s, y: 4 * s),
                        control: CGPoint(x: 9 * s, y: (state == .begeistert ? 11 : 8) * s)
                    )
                }
                .stroke(.white.opacity(0.5), lineWidth: 1.5 * s)
                .frame(width: 20 * s, height: 14 * s)
                .offset(y: 1 * s)
            }
        }
    }

    // MARK: - Eyes

    private var eyeGroup: some View {
        HStack(spacing: 6 * s) {
            singleEye(isLeft: true)
            singleEye(isLeft: false)
        }
    }

    private func singleEye(isLeft: Bool) -> some View {
        ZStack {
            // Eye white
            Ellipse()
                .fill(.white)
                .frame(width: eyeSize, height: eyeSize * blinkScale)
                .shadow(color: .black.opacity(0.05), radius: 1, y: 1)

            if blinkScale > 0.3 {
                // Pupil
                Circle()
                    .fill(.black)
                    .frame(width: pupilSize, height: pupilSize)
                    .offset(x: (isLeft ? 0.5 : 1) * s, y: 0.5 * s)

                // Eye glint
                Circle()
                    .fill(.white)
                    .frame(width: glintSize, height: glintSize)
                    .offset(x: (isLeft ? 1.5 : 2) * s, y: -1.5 * s)

                // Star eyes for excited state
                if state == .begeistert {
                    Image(systemName: "star.fill")
                        .font(.system(size: 5 * s))
                        .foregroundStyle(AppTheme.sunshine)
                        .offset(x: 0.5 * s, y: 0.5 * s)
                }
            }

            // Squint for cold
            if state == .frierend {
                Capsule()
                    .fill(.black.opacity(0.6))
                    .frame(width: eyeSize * 0.8, height: 2 * s)
                    .offset(y: 2 * s)
            }

            // Worried eyebrow
            if state == .zoegernd || state == .warnend {
                Capsule()
                    .fill(.black.opacity(0.5))
                    .frame(width: eyeSize * 0.7, height: 1.5 * s)
                    .rotationEffect(.degrees(isLeft ? 10 : -10))
                    .offset(y: -(eyeSize * 0.6))
            }
        }
    }

    private var eyeSize: CGFloat {
        switch state {
        case .begeistert: return 14 * s
        case .frierend: return 10 * s
        default: return 12 * s
        }
    }

    private var pupilSize: CGFloat {
        switch state {
        case .begeistert: return 6 * s
        case .warnend: return 4 * s
        default: return 5 * s
        }
    }

    private var glintSize: CGFloat { 2.5 * s }

    // MARK: - Wing

    private var wing: some View {
        Ellipse()
            .fill(
                LinearGradient(
                    colors: [state.bodyColor.opacity(0.5), state.bodyColor.opacity(0.3)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .frame(width: 22 * s, height: 14 * s)
            .rotationEffect(.degrees(15))
    }

    // MARK: - Tail

    private var tail: some View {
        ZStack {
            Capsule()
                .fill(state.bodyColor.opacity(0.5))
                .frame(width: 10 * s, height: 4 * s)
                .rotationEffect(.degrees(-20))
            Capsule()
                .fill(state.bodyColor.opacity(0.4))
                .frame(width: 8 * s, height: 3 * s)
                .rotationEffect(.degrees(-35))
                .offset(y: -3 * s)
        }
    }

    // MARK: - Hair tuft

    private var hairTuft: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(state.bodyColor.opacity(0.65))
                    .frame(width: 2.5 * s, height: (8 + CGFloat(i) * 2) * s)
                    .rotationEffect(.degrees(Double(i - 1) * 20))
                    .offset(x: CGFloat(i - 1) * 3 * s, y: CGFloat(2 - i) * s)
            }
        }
    }

    // MARK: - Decorations

    @ViewBuilder
    private var decorations: some View {
        switch state {
        case .begeistert:
            Group {
                sparkle(x: 36, y: -38, size: 12)
                sparkle(x: -30, y: -44, size: 9)
                sparkle(x: 38, y: 5, size: 7)
            }
        case .frierend:
            Group {
                snowflake(x: -32, y: -28, size: 11)
                snowflake(x: 36, y: -42, size: 8)
                snowflake(x: -18, y: -48, size: 6)
            }
        case .warnend:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12 * s))
                .foregroundStyle(AppTheme.coral)
                .offset(x: 34 * s, y: -44 * s + bobOffset)
        case .zoegernd:
            Text("?")
                .font(.system(size: 14 * s, weight: .heavy, design: .rounded))
                .foregroundStyle(AppTheme.sunshine.opacity(0.6))
                .offset(x: 34 * s, y: -42 * s + bobOffset)
        default:
            EmptyView()
        }
    }

    private func sparkle(x: CGFloat, y: CGFloat, size: CGFloat) -> some View {
        Image(systemName: "sparkle")
            .font(.system(size: size * s))
            .foregroundStyle(AppTheme.sunshine)
            .opacity(sparkleOpacity)
            .offset(x: x * s, y: y * s + bobOffset)
    }

    private func snowflake(x: CGFloat, y: CGFloat, size: CGFloat) -> some View {
        Image(systemName: "snowflake")
            .font(.system(size: size * s))
            .foregroundStyle(AppTheme.skyBlue.opacity(0.6))
            .offset(x: x * s, y: y * s + bobOffset)
    }

    // MARK: - Animations

    private func startAnimations() {
        let bobAmount: CGFloat = state == .frierend ? -4 : -2.5
        let bobDuration: Double = state == .frierend ? 0.6 : 2.2

        withAnimation(.easeInOut(duration: bobDuration).repeatForever(autoreverses: true)) {
            bobOffset = bobAmount * s
        }

        let wingTarget: Double = state == .begeistert ? -22 : -4
        let wingSpeed: Double = state == .begeistert ? 0.35 : 2.5
        withAnimation(.easeInOut(duration: wingSpeed).repeatForever(autoreverses: true)) {
            wingAngle = wingTarget
        }

        if state == .begeistert || state == .zufrieden {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                blushOpacity = state == .begeistert ? 0.4 : 0.2
            }
        } else {
            blushOpacity = 0
        }

        if state == .begeistert {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                sparkleOpacity = 1
            }
        } else {
            sparkleOpacity = 0
        }

        scheduleBlink()
    }

    private func scheduleBlink() {
        blinkTask?.cancel()
        blinkTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double.random(in: 2...5)))
                guard !Task.isCancelled else { break }
                withAnimation(.easeInOut(duration: 0.06)) { blinkScale = 0.05 }
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { break }
                withAnimation(.easeInOut(duration: 0.06)) { blinkScale = 1 }
            }
        }
    }
}

// MARK: - Map Pin

struct DuckPinView: View {
    let state: DuckState

    var body: some View {
        ZStack {
            Circle()
                .fill(state.bodyColor.opacity(0.2))
                .frame(width: 38, height: 38)

            Circle()
                .fill(state.bodyColor)
                .frame(width: 30, height: 30)
                .shadow(color: state.bodyColor.opacity(0.3), radius: 4, y: 2)

            Text(state.emoji)
                .font(.system(size: 15))
        }
    }
}

// MARK: - Small badge

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
        HStack(spacing: 20) {
            ForEach(DuckState.allCases, id: \.rawValue) { state in
                VStack(spacing: 10) {
                    DuckView(state: state, size: 110)
                    Text(state.title)
                        .font(AppTheme.cardTitle)
                    Text(state.line)
                        .font(AppTheme.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(width: 120)
                }
                .padding()
                .background(state.backgroundGradient, in: RoundedRectangle(cornerRadius: 20))
            }
        }
        .padding()
    }
}
