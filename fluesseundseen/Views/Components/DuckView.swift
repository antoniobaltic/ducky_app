import SwiftUI

// MARK: - Ducky Mascot

struct DuckView: View {
    let state: DuckState
    var size: CGFloat = 120

    @State private var bobOffset: CGFloat = 0
    @State private var blinkScale: CGFloat = 1
    @State private var wingAngle: Double = 0
    @State private var cheekGlow: Double = 0
    @State private var sparkleOpacity: Double = 0
    @State private var bodyTilt: Double = 0
    @State private var beakGap: CGFloat = 0
    @State private var decorFloat: CGFloat = 0
    @State private var entryScale: CGFloat = 0.6
    @State private var blinkTask: Task<Void, Never>?

    private var s: CGFloat { size / 120 }
    private var isCompact: Bool { size < 42 }

    var body: some View {
        ZStack {
            if !isCompact { waterRipple }
            duckBody
                .rotationEffect(.degrees(bodyTilt))
        }
        .frame(width: size, height: size)
        .scaleEffect(entryScale)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
                entryScale = 1
            }
            startAnimations()
        }
        .onChange(of: state) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                entryScale = 0.88
            }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(120))
                withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
                    entryScale = 1
                }
            }
            startAnimations()
        }
        .onDisappear { blinkTask?.cancel() }
    }

    // MARK: - Water Ripple

    private var waterRipple: some View {
        ZStack {
            Ellipse()
                .fill(state.accentColor.opacity(0.08))
                .frame(width: 76 * s, height: 14 * s)
                .offset(y: 46 * s + bobOffset * 0.8)
                .blur(radius: 4 * s)
            Ellipse()
                .fill(state.accentColor.opacity(0.04))
                .frame(width: 96 * s, height: 10 * s)
                .offset(y: 49 * s + bobOffset * 0.5)
                .blur(radius: 6 * s)
        }
    }

    // MARK: - Duck Composition

    private var duckBody: some View {
        ZStack {
            // Body
            bodyShape
                .offset(y: 20 * s + bobOffset)

            // Belly shine
            Ellipse()
                .fill(.white.opacity(0.28))
                .frame(width: 32 * s, height: 20 * s)
                .offset(x: -5 * s, y: 24 * s + bobOffset)
                .blur(radius: 3 * s)

            // Wing
            if !isCompact {
                wing
                    .offset(x: 20 * s, y: 24 * s + bobOffset)
                    .rotationEffect(.degrees(wingAngle), anchor: .leading)
            }

            // Tail
            if !isCompact {
                tail.offset(x: -30 * s, y: 10 * s + bobOffset)
            }

            // Head (bigger than body = kawaii)
            headShape
                .offset(x: 2 * s, y: -14 * s + bobOffset)

            // Head shine
            Ellipse()
                .fill(.white.opacity(0.28))
                .frame(width: 20 * s, height: 14 * s)
                .rotationEffect(.degrees(-25))
                .offset(x: -8 * s, y: -28 * s + bobOffset)
                .blur(radius: 2.5 * s)

            // Cheeks
            cheeks.offset(y: bobOffset)

            // Beak
            beakView.offset(x: 27 * s, y: -10 * s + bobOffset)

            // Eyes
            eyeGroup.offset(x: 6 * s, y: -20 * s + bobOffset)

            // Sunglasses (begeistert only)
            if state == .begeistert && !isCompact {
                sunglasses.offset(x: 6 * s, y: -20 * s + bobOffset)
            }

            // Hair tuft
            if !isCompact {
                hairTuft.offset(x: -2 * s, y: -42 * s + bobOffset)
            }

            // State decorations
            if !isCompact {
                decorations
            }
        }
    }

    // MARK: - Body

    private var bodyShape: some View {
        Ellipse()
            .fill(
                EllipticalGradient(
                    colors: [
                        state.bodyColor,
                        state.bodyColor.opacity(0.88),
                        state.bodyColor.opacity(0.72)
                    ],
                    center: .init(x: 0.38, y: 0.28),
                    startRadiusFraction: 0.0,
                    endRadiusFraction: 0.7
                )
            )
            .frame(width: 64 * s, height: 46 * s)
            .shadow(color: state.bodyColor.opacity(0.15), radius: 3 * s, y: 2 * s)
    }

    // MARK: - Head

    private var headShape: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [state.bodyColor, state.bodyColor.opacity(0.88)],
                    center: .init(x: 0.4, y: 0.32),
                    startRadius: 0,
                    endRadius: 28 * s
                )
            )
            .frame(width: 54 * s, height: 54 * s)
            .shadow(color: state.bodyColor.opacity(0.12), radius: 3 * s, y: 1 * s)
    }

    // MARK: - Eyes

    private var eyeGroup: some View {
        HStack(spacing: eyeSpacing) {
            singleEye(isLeft: true)
            singleEye(isLeft: false)
        }
    }

    private var eyeSpacing: CGFloat {
        (state == .begeistert ? 8 : 6) * s
    }

    private func singleEye(isLeft: Bool) -> some View {
        ZStack {
            // Eye white
            Ellipse()
                .fill(.white)
                .frame(width: eyeWidth, height: eyeHeight * blinkScale)
                .shadow(color: .black.opacity(0.06), radius: 1 * s, y: 1 * s)

            if blinkScale > 0.3 {
                // Pupil
                Circle()
                    .fill(Color(white: 0.1))
                    .frame(width: pupilSize, height: pupilSize)
                    .offset(x: pupilOffsetX(isLeft: isLeft), y: pupilOffsetY)

                // Glint
                Circle()
                    .fill(.white)
                    .frame(width: glintSize, height: glintSize)
                    .offset(x: (isLeft ? 1.5 : 2) * s, y: -2 * s)

                // Second glint for excited
                if state == .begeistert {
                    Circle()
                        .fill(.white.opacity(0.7))
                        .frame(width: glintSize * 0.55, height: glintSize * 0.55)
                        .offset(x: -1.5 * s, y: 1.5 * s)
                }

                // Star eyes for excited
                if state == .begeistert {
                    Image(systemName: "star.fill")
                        .font(.system(size: 5.5 * s))
                        .foregroundStyle(AppTheme.sunshine)
                        .offset(x: pupilOffsetX(isLeft: isLeft), y: pupilOffsetY)
                }
            }

            // Squint overlay for disgusted (raised lower lid)
            if state == .frierend {
                Capsule()
                    .fill(state.bodyColor)
                    .frame(width: eyeWidth * 1.15, height: eyeHeight * 0.45)
                    .offset(y: eyeHeight * 0.30)
            }

            // Eyebrows
            if shouldShowEyebrow {
                eyebrow(isLeft: isLeft)
                    .offset(y: -(eyeHeight * 0.55 + 2 * s))
            }
        }
    }

    private var eyeWidth: CGFloat {
        switch state {
        case .begeistert: return 16 * s
        case .zufrieden:  return 14 * s
        case .zoegernd:   return 13 * s
        case .frierend:   return 13 * s
        case .warnend:    return 14 * s
        }
    }

    private var eyeHeight: CGFloat {
        switch state {
        case .begeistert: return 16 * s
        case .zufrieden:  return 12 * s
        case .zoegernd:   return 13 * s
        case .frierend:   return 11 * s
        case .warnend:    return 13 * s
        }
    }

    private var pupilSize: CGFloat {
        switch state {
        case .begeistert: return 7 * s
        case .zufrieden:  return 5.5 * s
        case .zoegernd:   return 5 * s
        case .frierend:   return 4.5 * s
        case .warnend:    return 4 * s
        }
    }

    private func pupilOffsetX(isLeft: Bool) -> CGFloat {
        switch state {
        case .zoegernd: return 2.5 * s   // side-eye
        default:        return (isLeft ? 0.5 : 1) * s
        }
    }

    private var pupilOffsetY: CGFloat {
        switch state {
        case .warnend: return -0.5 * s
        default:       return 0.5 * s
        }
    }

    private var glintSize: CGFloat { 2.8 * s }

    private var shouldShowEyebrow: Bool {
        state == .zoegernd || state == .warnend || state == .frierend
    }

    private func eyebrow(isLeft: Bool) -> some View {
        Capsule()
            .fill(Color(white: 0.25).opacity(eyebrowOpacity))
            .frame(width: eyeWidth * 0.75, height: 2 * s)
            .rotationEffect(.degrees(eyebrowAngle(isLeft: isLeft)))
    }

    private var eyebrowOpacity: Double {
        switch state {
        case .warnend:  return 0.7
        case .zoegernd: return 0.5
        case .frierend: return 0.65
        default:        return 0
        }
    }

    private func eyebrowAngle(isLeft: Bool) -> Double {
        switch state {
        case .warnend:  return isLeft ? -20 : 20
        case .zoegernd: return isLeft ? 15 : -5
        case .frierend: return isLeft ? 20 : -20
        default:        return 0
        }
    }

    // MARK: - Sunglasses

    private var sunglasses: some View {
        ZStack {
            // Arms (behind lenses)
            Capsule()
                .fill(Color(white: 0.32))
                .frame(width: 11 * s, height: 2 * s)
                .offset(x: -22 * s)
            Capsule()
                .fill(Color(white: 0.32))
                .frame(width: 11 * s, height: 2 * s)
                .offset(x: 22 * s)

            // Left lens
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.08), Color(white: 0.22)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(width: 19 * s, height: 13 * s)
                .overlay(Ellipse().stroke(Color(white: 0.44), lineWidth: 1.5 * s))
                .offset(x: -12 * s)

            // Left lens glint
            Ellipse()
                .fill(.white.opacity(0.26))
                .frame(width: 6 * s, height: 3 * s)
                .offset(x: -16 * s, y: -2.5 * s)
                .blur(radius: 0.8 * s)

            // Right lens
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.08), Color(white: 0.22)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(width: 19 * s, height: 13 * s)
                .overlay(Ellipse().stroke(Color(white: 0.44), lineWidth: 1.5 * s))
                .offset(x: 12 * s)

            // Right lens glint
            Ellipse()
                .fill(.white.opacity(0.26))
                .frame(width: 6 * s, height: 3 * s)
                .offset(x: 8 * s, y: -2.5 * s)
                .blur(radius: 0.8 * s)

            // Bridge
            Capsule()
                .fill(Color(white: 0.44))
                .frame(width: 6 * s, height: 2 * s)
        }
    }

    // MARK: - Beak

    private var beakView: some View {
        ZStack {
            // Upper beak
            RoundedRectangle(cornerRadius: 7 * s)
                .fill(
                    LinearGradient(
                        colors: [state.billColor, state.billColor.opacity(0.85)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: 21 * s, height: 11 * s)
                .offset(y: -2 * s)

            // Lower beak
            RoundedRectangle(cornerRadius: 5 * s)
                .fill(state.billColor.opacity(0.75))
                .frame(width: 18 * s, height: 8 * s)
                .offset(y: 5 * s + beakGap)

            // Mouth interior (visible when open)
            if beakOpenAmount > 1.5 * s {
                Ellipse()
                    .fill(Color(red: 0.92, green: 0.42, blue: 0.42))
                    .frame(width: 11 * s, height: beakOpenAmount * 0.7)
                    .offset(y: 2 * s + beakGap * 0.5)
            }

            // Smile line
            if state == .zufrieden {
                Path { p in
                    p.move(to: CGPoint(x: 2 * s, y: 4 * s))
                    p.addQuadCurve(
                        to: CGPoint(x: 16 * s, y: 4 * s),
                        control: CGPoint(x: 9 * s, y: 8 * s)
                    )
                }
                .stroke(.white.opacity(0.4), lineWidth: 1.5 * s)
                .frame(width: 20 * s, height: 14 * s)
            }

            // Frown line for disgusted
            if state == .frierend {
                Path { p in
                    p.move(to: CGPoint(x: 2 * s, y: 8 * s))
                    p.addQuadCurve(
                        to: CGPoint(x: 16 * s, y: 8 * s),
                        control: CGPoint(x: 9 * s, y: 3 * s)
                    )
                }
                .stroke(.white.opacity(0.35), lineWidth: 1.5 * s)
                .frame(width: 20 * s, height: 14 * s)
            }
        }
    }

    private var beakOpenAmount: CGFloat {
        switch state {
        case .begeistert: return 4 * s
        case .zoegernd:   return 1.5 * s
        default:          return 0
        }
    }

    // MARK: - Cheeks

    private var cheeks: some View {
        Group {
            Circle()
                .fill(cheekColor.opacity(cheekGlow))
                .frame(width: 11 * s, height: 8 * s)
                .offset(x: 21 * s, y: -5 * s)
                .blur(radius: 3 * s)

            if state == .begeistert || state == .zufrieden {
                Circle()
                    .fill(cheekColor.opacity(cheekGlow * 0.5))
                    .frame(width: 8 * s, height: 6 * s)
                    .offset(x: -8 * s, y: -3 * s)
                    .blur(radius: 3 * s)
            }
        }
    }

    private var cheekColor: Color {
        switch state {
        case .begeistert: return .pink
        case .zufrieden:  return .pink
        case .zoegernd:   return .clear
        case .frierend:   return Color(red: 0.55, green: 0.82, blue: 0.38)
        case .warnend:    return Color(red: 1.0, green: 0.4, blue: 0.3)
        }
    }

    // MARK: - Wing

    private var wing: some View {
        Ellipse()
            .fill(
                LinearGradient(
                    colors: [state.bodyColor.opacity(0.55), state.bodyColor.opacity(0.3)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .frame(width: 22 * s, height: 14 * s)
            .rotationEffect(.degrees(15))
    }

    // MARK: - Tail

    private var tail: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(state.bodyColor.opacity(0.5 - Double(i) * 0.08))
                    .frame(width: (9 - CGFloat(i)) * s, height: (3.5 + CGFloat(i) * 0.5) * s)
                    .rotationEffect(.degrees(Double(i - 1) * -18))
                    .offset(x: -CGFloat(i) * 2 * s, y: CGFloat(1 - i) * 3 * s)
            }
        }
    }

    // MARK: - Hair Tuft

    private var hairTuft: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(state.bodyColor.opacity(0.7))
                    .frame(width: 3 * s, height: (9 + CGFloat(i) * 2.5) * s)
                    .rotationEffect(.degrees(Double(i - 1) * 22))
                    .offset(x: CGFloat(i - 1) * 3.5 * s, y: CGFloat(2 - i) * 1.5 * s)
            }
        }
    }

    // MARK: - Decorations

    @ViewBuilder
    private var decorations: some View {
        switch state {
        case .begeistert:
            Group {
                sparkle(x: 36, y: -40, size: 13)
                sparkle(x: -32, y: -46, size: 10)
                sparkle(x: 40, y: 4, size: 8)
                Image(systemName: "heart.fill")
                    .font(.system(size: 7 * s))
                    .foregroundStyle(AppTheme.warmPink)
                    .opacity(sparkleOpacity * 0.8)
                    .offset(x: -38 * s, y: -30 * s + bobOffset + decorFloat)
            }

        case .zufrieden:
            sparkle(x: 34, y: -42, size: 8)

        case .zoegernd:
            Group {
                Text("?")
                    .font(.system(size: 15 * s, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.sunshine.opacity(0.5))
                    .offset(x: 34 * s, y: -44 * s + bobOffset + decorFloat)
                Image(systemName: "drop.fill")
                    .font(.system(size: 6 * s))
                    .foregroundStyle(AppTheme.skyBlue.opacity(0.5))
                    .offset(x: -24 * s, y: -32 * s + bobOffset)
            }

        case .frierend:
            Group {
                // Nausea waveform
                Image(systemName: "waveform")
                    .font(.system(size: 11 * s))
                    .foregroundStyle(Color(red: 0.28, green: 0.70, blue: 0.28).opacity(0.7))
                    .opacity(sparkleOpacity * 0.9)
                    .offset(x: -34 * s, y: -30 * s + bobOffset + decorFloat)
                // Disgust swirl tilde
                Text("~")
                    .font(.system(size: 18 * s, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 0.3, green: 0.72, blue: 0.3).opacity(0.55))
                    .opacity(sparkleOpacity)
                    .offset(x: 32 * s, y: -46 * s + bobOffset + decorFloat * 0.8)
                // Sick glow dot
                Circle()
                    .fill(Color(red: 0.4, green: 0.78, blue: 0.4).opacity(0.35))
                    .frame(width: 7 * s, height: 7 * s)
                    .offset(x: -18 * s, y: -50 * s + bobOffset)
                    .blur(radius: 2 * s)
                    .opacity(sparkleOpacity * 0.7)
            }

        case .warnend:
            Group {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13 * s))
                    .foregroundStyle(AppTheme.coral)
                    .offset(x: 36 * s, y: -46 * s + bobOffset + decorFloat)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 7 * s))
                    .foregroundStyle(AppTheme.coral.opacity(0.6))
                    .offset(x: -30 * s, y: -38 * s + bobOffset)
                    .opacity(sparkleOpacity)
            }
        }
    }

    private func sparkle(x: CGFloat, y: CGFloat, size: CGFloat) -> some View {
        Image(systemName: "sparkle")
            .font(.system(size: size * s))
            .foregroundStyle(AppTheme.sunshine)
            .opacity(sparkleOpacity)
            .offset(x: x * s, y: y * s + bobOffset + decorFloat * (size / 13))
    }

    // MARK: - Animations

    private func startAnimations() {
        // Bob
        let bobAmount: CGFloat = state == .begeistert ? -7 : state == .frierend ? -2.5 : -3
        let bobDuration: Double = state == .begeistert ? 0.5 : state == .frierend ? 2.0 : 2.2
        withAnimation(.easeInOut(duration: bobDuration).repeatForever(autoreverses: true)) {
            bobOffset = bobAmount * s
        }

        // Wing flap
        let wingTarget: Double = state == .begeistert ? -32 : state == .warnend ? -8 : -4
        let wingSpeed: Double = state == .begeistert ? 0.3 : state == .warnend ? 0.8 : 2.5
        withAnimation(.easeInOut(duration: wingSpeed).repeatForever(autoreverses: true)) {
            wingAngle = wingTarget
        }

        // Body tilt per state
        let (tiltTarget, tiltDuration): (Double, Double) = {
            switch state {
            case .begeistert: return (8, 0.25)
            case .zufrieden:  return (2.5, 3)
            case .zoegernd:   return (-4, 2.5)
            case .frierend:   return (1.5, 2.5)
            case .warnend:    return (4, 0.6)
            }
        }()
        withAnimation(.easeInOut(duration: tiltDuration).repeatForever(autoreverses: true)) {
            bodyTilt = tiltTarget
        }

        // Beak gap always reset (no chatter)
        withAnimation(.easeInOut(duration: 0.2)) { beakGap = 0 }

        // Cheek glow
        let (cheekTarget, cheekDuration): (Double, Double) = {
            switch state {
            case .begeistert: return (0.5, 1.5)
            case .zufrieden:  return (0.25, 2)
            case .frierend:   return (0.2, 1.8)
            case .warnend:    return (0.35, 0.8)
            default:          return (0, 1)
            }
        }()
        withAnimation(.easeInOut(duration: cheekDuration).repeatForever(autoreverses: true)) {
            cheekGlow = cheekTarget
        }

        // Sparkle / decoration visibility
        let sparkleTarget: Double = (state == .zoegernd) ? 0.6 : 1
        let sparkleDuration: Double = state == .begeistert ? 0.8 : 1.4
        if state != .zufrieden || true {
            withAnimation(.easeInOut(duration: sparkleDuration).repeatForever(autoreverses: true)) {
                sparkleOpacity = sparkleTarget
            }
        }

        // Decoration float
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
            decorFloat = -4 * s
        }

        scheduleBlink()
    }

    private func scheduleBlink() {
        blinkTask?.cancel()
        blinkTask = Task { @MainActor in
            while !Task.isCancelled {
                let interval = Double.random(in: 2.5...5)
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { break }

                // Blink
                withAnimation(.easeInOut(duration: 0.06)) { blinkScale = 0.05 }
                try? await Task.sleep(for: .milliseconds(80))
                guard !Task.isCancelled else { break }
                withAnimation(.easeInOut(duration: 0.08)) { blinkScale = 1 }

                // Occasional double-blink
                if Bool.random() {
                    try? await Task.sleep(for: .milliseconds(200))
                    guard !Task.isCancelled else { break }
                    withAnimation(.easeInOut(duration: 0.05)) { blinkScale = 0.05 }
                    try? await Task.sleep(for: .milliseconds(60))
                    guard !Task.isCancelled else { break }
                    withAnimation(.easeInOut(duration: 0.08)) { blinkScale = 1 }
                }
            }
        }
    }
}

// MARK: - Map Pin (mini duck face, not emoji)

struct DuckPinView: View {
    let state: DuckState

    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(state.bodyColor.opacity(0.2))
                .frame(width: 38, height: 38)

            // Head circle
            Circle()
                .fill(
                    RadialGradient(
                        colors: [state.bodyColor, state.bodyColor.opacity(0.85)],
                        center: .init(x: 0.4, y: 0.35),
                        startRadius: 0,
                        endRadius: 15
                    )
                )
                .frame(width: 30, height: 30)
                .shadow(color: state.bodyColor.opacity(0.3), radius: 4, y: 2)

            // Head shine
            Circle()
                .fill(.white.opacity(0.22))
                .frame(width: 10, height: 8)
                .offset(x: -4, y: -6)
                .blur(radius: 2)

            // Eyes
            HStack(spacing: 4) {
                pinEye
                pinEye
            }
            .offset(x: 1, y: -2)

            // Beak
            Ellipse()
                .fill(state.billColor)
                .frame(width: 9, height: 6)
                .offset(x: 5, y: 4)

            // Tiny cheek
            Circle()
                .fill(Color.pink.opacity(state == .begeistert || state == .zufrieden ? 0.3 : 0))
                .frame(width: 5, height: 5)
                .offset(x: 8, y: 1)
                .blur(radius: 2)
        }
    }

    private var pinEye: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 6, height: 6)
            Circle()
                .fill(Color(white: 0.1))
                .frame(width: 3.5, height: 3.5)
            Circle()
                .fill(.white)
                .frame(width: 1.5, height: 1.5)
                .offset(x: 0.5, y: -0.8)
        }
    }
}

// MARK: - Small Badge

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
                        .frame(width: 140)
                }
                .padding()
                .background(state.backgroundGradient, in: RoundedRectangle(cornerRadius: 20))
            }
        }
        .padding()
    }
}

#Preview("Ducky Sizes") {
    HStack(spacing: 24) {
        DuckView(state: .begeistert, size: 28)
        DuckView(state: .zufrieden, size: 48)
        DuckView(state: .zoegernd, size: 80)
        DuckView(state: .frierend, size: 120)
    }
    .padding()
}

#Preview("Duck Pin") {
    HStack(spacing: 16) {
        ForEach(DuckState.allCases, id: \.rawValue) { state in
            DuckPinView(state: state)
        }
    }
    .padding()
}
